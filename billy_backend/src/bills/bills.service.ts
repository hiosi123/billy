import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Bill } from './bill.entity';
import { Room } from '../rooms/room.entity';
import { RoomsService } from '../rooms/rooms.service';
import { CreateBillDto } from './dto/create-bill.dto';
import { UsageDto } from './dto/usage.dto';
import { CalculateBillDto } from './dto/calculate-bill.dto';
import { BillCalc, calculateDifference } from './bill-calc';

/** 조건 조회 결과(bills + rooms + floors 조인). 기존 Go 의 BillInfo. */
export interface BillInfo {
  billId: number;
  waterUsage: number;
  waterBill: number;
  waterMeasure: number;
  electricityUsage: number;
  electricityBill: number;
  electricityMeasure: number;
  chargeMonth: string;
  roomId: number;
  floorId: number;
  buildingId: number;
  roomNumber: number;
  roomName: string;
  floor: number;
}

/** YYYYMM 한 달 빼기. */
function prevMonth(yyyymm: string): string {
  const year = parseInt(yyyymm.slice(0, 4), 10);
  const month = parseInt(yyyymm.slice(4, 6), 10);
  const d = new Date(Date.UTC(year, month - 1, 1));
  d.setUTCMonth(d.getUTCMonth() - 1);
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  return `${y}${m}`;
}

@Injectable()
export class BillsService {
  constructor(
    @InjectRepository(Bill) private billsRepo: Repository<Bill>,
    private roomsService: RoomsService,
  ) {}

  findAll() {
    return this.billsRepo.find();
  }

  async findOne(id: number) {
    const bill = await this.billsRepo.findOne({ where: { billId: id } });
    if (!bill) throw new NotFoundException('청구를 찾을 수 없습니다');
    return bill;
  }

  getByMonth(month: string, buildingId: number) {
    return this.billsRepo.find({ where: { chargeMonth: month, buildingId } });
  }

  create(dto: CreateBillDto) {
    return this.billsRepo.save(this.billsRepo.create(dto));
  }

  async update(id: number, dto: Partial<Bill>) {
    await this.findOne(id);
    await this.billsRepo.update({ billId: id }, dto);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.billsRepo.delete({ billId: id });
    return { message: '청구가 삭제되었습니다' };
  }

  /** 월/호실/층/건물 조건으로 조인 조회. (Go: GetBillsByCondition) */
  async getByCondition(month: string, roomId: number, floorId: number, buildingId: number): Promise<BillInfo[]> {
    const qb = this.billsRepo
      .createQueryBuilder('b')
      .leftJoin('rooms', 'r', 'b.room_id = r.room_id')
      .leftJoin('floors', 'f', 'b.floor_id = f.floor_id')
      // Postgres는 따옴표 없는 별칭을 소문자로 접으므로 camelCase 별칭은 큰따옴표로 보존한다.
      .select([
        'b.bill_id AS "billId"',
        'b.water_usage AS "waterUsage"',
        'b.water_bill AS "waterBill"',
        'b.water_measure AS "waterMeasure"',
        'b.electricity_usage AS "electricityUsage"',
        'b.electricity_bill AS "electricityBill"',
        'b.electricity_measure AS "electricityMeasure"',
        'b.charge_month AS "chargeMonth"',
        'b.room_id AS "roomId"',
        'b.floor_id AS "floorId"',
        'b.building_id AS "buildingId"',
        'r.room_number AS "roomNumber"',
        'r.room_name AS "roomName"',
        'f.floor AS "floor"',
      ]);

    if (month) qb.andWhere('b.charge_month = :month', { month });
    if (roomId) qb.andWhere('b.room_id = :roomId', { roomId });
    if (floorId) qb.andWhere('b.floor_id = :floorId', { floorId });
    if (buildingId) qb.andWhere('b.building_id = :buildingId', { buildingId });

    const rows = await qb.getRawMany();
    return rows.map((r) => ({
      billId: Number(r.billId),
      waterUsage: parseFloat(r.waterUsage) || 0,
      waterBill: parseFloat(r.waterBill) || 0,
      waterMeasure: parseFloat(r.waterMeasure) || 0,
      electricityUsage: parseFloat(r.electricityUsage) || 0,
      electricityBill: parseFloat(r.electricityBill) || 0,
      electricityMeasure: parseFloat(r.electricityMeasure) || 0,
      chargeMonth: r.chargeMonth,
      roomId: Number(r.roomId),
      floorId: Number(r.floorId),
      buildingId: Number(r.buildingId),
      roomNumber: Number(r.roomNumber),
      roomName: r.roomName,
      floor: Number(r.floor),
    }));
  }

  /**
   * 검침값 입력 → 지난달 대비 사용량 계산 후 이번달 청구 생성/갱신. (Go: InsertMeasure)
   */
  async insertMeasure(usage: UsageDto) {
    if (!/^\d{6}$/.test(usage.ChargeMonth)) {
      throw new BadRequestException('charge month 형식이 올바르지 않습니다 (YYYYMM)');
    }
    const lastMonth = prevMonth(usage.ChargeMonth);

    const lastMonthBills = await this.getByMonth(lastMonth, usage.BuildingId);
    const thisMonthBills = await this.getByMonth(usage.ChargeMonth, usage.BuildingId);

    const thisMonthBillsMap = new Map<number, Bill>();
    for (const b of thisMonthBills) thisMonthBillsMap.set(b.roomId, b);

    const rooms = await this.roomsService.findByBuildingId(usage.BuildingId);
    const roomMultiplyMap = new Map<number, Room>();
    for (const r of rooms) roomMultiplyMap.set(r.roomId, r);

    const defaultMulti = (): Partial<Room> => ({ measureMultiply: 1, strictWater: 0, strictElectricity: 0 });

    let newBill: Bill | null = null;
    let matchFound = false;

    // 1. 지난달 청구 중 입력값과 일치하는 방을 찾아 이번달 청구 생성/갱신
    for (const lmb of lastMonthBills) {
      if (
        usage.BuildingId === lmb.buildingId &&
        usage.FloorId === lmb.floorId &&
        usage.RoomId === lmb.roomId
      ) {
        matchFound = true;
        const multi = roomMultiplyMap.get(usage.RoomId) ?? (defaultMulti() as Room);

        const bill: Partial<Bill> = {
          waterMeasure: usage.WaterMeasure,
          waterUsage: calculateDifference(lmb.waterMeasure, usage.WaterMeasure, 1),
          electricityMeasure: usage.ElectricityMeasure,
          electricityUsage: calculateDifference(lmb.electricityMeasure, usage.ElectricityMeasure, multi.measureMultiply ?? 1),
          roomId: usage.RoomId,
          floorId: usage.FloorId,
          buildingId: usage.BuildingId,
          chargeMonth: usage.ChargeMonth,
        };

        if ((multi.strictWater ?? 0) > 0) bill.waterUsage = multi.strictWater;
        if ((multi.strictElectricity ?? 0) > 0) bill.electricityUsage = multi.strictElectricity;

        const existing = await this.getByCondition(usage.ChargeMonth, usage.RoomId, usage.FloorId, usage.BuildingId);
        if (existing.length > 0) {
          bill.billId = existing[0].billId;
          await this.billsRepo.update({ billId: existing[0].billId }, bill);
          newBill = await this.findOne(existing[0].billId);
        } else {
          newBill = await this.billsRepo.save(this.billsRepo.create(bill));
        }
        break;
      }
    }

    // 2. 나머지 방들: 이번달 청구가 이미 있으면 지난달 대비 사용량 재계산 후 갱신
    for (const lmb of lastMonthBills) {
      if (usage.BuildingId === lmb.buildingId && usage.FloorId === lmb.floorId && usage.RoomId === lmb.roomId) {
        continue;
      }
      const thisMonthBill = thisMonthBillsMap.get(lmb.roomId);
      if (!thisMonthBill) continue;

      const multi = roomMultiplyMap.get(lmb.roomId) ?? (defaultMulti() as Room);

      thisMonthBill.waterUsage = calculateDifference(lmb.waterMeasure, thisMonthBill.waterMeasure, 1);
      thisMonthBill.electricityUsage = calculateDifference(
        lmb.electricityMeasure,
        thisMonthBill.electricityMeasure,
        multi.measureMultiply ?? 1,
      );
      if ((multi.strictWater ?? 0) > 0) thisMonthBill.waterUsage = multi.strictWater;
      if ((multi.strictElectricity ?? 0) > 0) thisMonthBill.electricityUsage = multi.strictElectricity;

      try {
        await this.billsRepo.update({ billId: thisMonthBill.billId }, {
          waterUsage: thisMonthBill.waterUsage,
          electricityUsage: thisMonthBill.electricityUsage,
        });
      } catch {
        // 한 방 갱신 실패가 전체를 막지 않도록 무시 (Go FIX 9 동일)
        continue;
      }
    }

    if (!matchFound) {
      throw new NotFoundException('지난달 청구에서 일치하는 항목을 찾을 수 없습니다');
    }
    return newBill;
  }

  /**
   * 관리비 계산: 호실별 전기 공용요금 안분, 세금/기금, 수도 안분 후
   * bills.electricity_bill / water_bill 갱신. (Go: CalculateBill)
   * 반환: roomNumber → 계산 결과 맵.
   */
  async calculate(req: CalculateBillDto): Promise<Record<number, BillCalc>> {
    const costPerKWh = req.ElectricityTotalCost / req.ElectricityTotalUsage;

    const bills = await this.getByMonth(req.Month, req.BuildingId);
    const rooms = await this.roomsService.findByBuildingId(req.BuildingId);

    const roomMap = new Map<number, Room>(); // roomId -> Room
    const roomNoSpace = new Map<number, number>(); // roomNumber -> roomSpace
    let totalSpace = 0;

    for (const room of rooms) {
      roomMap.set(room.roomId, room);
      if (!roomNoSpace.has(room.roomNumber)) {
        roomNoSpace.set(room.roomNumber, room.roomSpace);
        totalSpace += room.roomSpace;
      }
    }

    const fBillsMap = new Map<number, BillCalc>(); // roomNumber -> BillCalc
    const billMap = new Map<number, Bill>(); // roomNumber -> 대표 bill (electricity/water_bill 기록용)
    let totalElectricityCommonCost = 0;
    let totalWaterUsage = 0;

    for (const bill of bills) {
      const room = roomMap.get(bill.roomId);
      if (!room) continue;
      const roomNumber = room.roomNumber;

      const existing = fBillsMap.get(roomNumber);
      if (existing) {
        existing.waterUsage += bill.waterUsage;
        existing.electricityUsage += bill.electricityUsage;
        existing.calculateElectricityCost(bill.electricityUsage, costPerKWh);
        totalElectricityCommonCost += existing.electricityCost;
        totalWaterUsage += bill.waterUsage;
      } else {
        const fb = new BillCalc();
        fb.waterUsage = bill.waterUsage;
        fb.electricityUsage = bill.electricityUsage;
        fb.buildingId = req.BuildingId;
        fb.roomNumber = roomNumber;
        fb.calculateElectricityCost(bill.electricityUsage, costPerKWh);
        totalElectricityCommonCost += fb.electricityCost;
        totalWaterUsage += bill.waterUsage;
        fBillsMap.set(roomNumber, fb);
        billMap.set(roomNumber, bill);
      }
    }

    for (const [roomNo, fBill] of fBillsMap) {
      fBill.calculateElectricityCost(fBill.electricityUsage, costPerKWh);
      const totalCommonCost = fBill.calculateTotalCommonCost(req.ElectricityTotalCost, totalElectricityCommonCost);

      const roomSpace = roomNoSpace.get(roomNo) ?? 0;
      fBill.calculateElectricityCommonCost(totalCommonCost, roomSpace, totalSpace);

      fBill.calculateElectricityTax();
      fBill.calculateElectricityFund();
      fBill.calculateWaterCostSupply(req.WaterSupplyCost, totalWaterUsage, fBill.waterUsage);
      fBill.calculateWaterCostSewer(req.WaterSewerCost, totalWaterUsage, fBill.waterUsage);
      const commonWaterCost = fBill.calculateWaterCostCommon(req.WaterTotalCost, req.WaterSupplyCost, req.WaterSewerCost);
      fBill.calculateWaterCommonCost(commonWaterCost, totalWaterUsage, fBill.waterUsage);
      fBill.calculateTotal(2500); // TV 수신료 등 고정 2500 (Go 동일)

      fBill.roundMoney();

      const separateBill = billMap.get(roomNo);
      if (separateBill) {
        await this.billsRepo.update(
          { billId: separateBill.billId },
          { electricityBill: fBill.electricityCostTotal, waterBill: fBill.waterCostTotal },
        );
      }
    }

    const result: Record<number, BillCalc> = {};
    for (const [roomNo, fBill] of fBillsMap) result[roomNo] = fBill;
    return result;
  }
}
