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
  waterMeterPhoto: string | null;
  electricityMeterPhoto: string | null;
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

/** bills.electricity_bill / water_bill 은 numeric(10,2) — 절댓값 1억 미만만 들어간다. */
const MAX_AMOUNT = 1e8;
/**
 * 호실 전기 사용량 합이 건물 전체(한전 고지서) 사용량의 이 배수를 넘으면 검침 오류로 본다.
 * 한전 검침일과 호실 검침일이 달라 조금 넘는 달은 있을 수 있어 여유를 둔다.
 */
const USAGE_SUM_TOLERANCE = 1.3;
/** 오류 메시지에 짚어 주는 호실 수. */
const MAX_SUSPECTS = 5;

const kwh = (n: number) => `${n.toLocaleString('ko-KR', { maximumFractionDigits: 2 })}kWh`;
const won = (n: number) => `${Math.round(n).toLocaleString('ko-KR')}원`;
/** 호실 표시 이름 — 같은 호수에 계량기가 여럿이면 계량기 명칭(천리안안과-1)으로 구분된다. */
const roomLabel = (room: Room) => `${room.roomNumber}호 ${room.measureMachine || room.roomName}`;

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
        'b.water_meter_photo AS "waterMeterPhoto"',
        'b.electricity_meter_photo AS "electricityMeterPhoto"',
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
      waterMeterPhoto: r.waterMeterPhoto ?? null,
      electricityMeterPhoto: r.electricityMeterPhoto ?? null,
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

        // 계량기 사진 URL(제공된 경우에만 갱신 — 구버전 클라이언트가 덮어쓰지 않도록)
        if (usage.WaterMeterPhoto !== undefined) bill.waterMeterPhoto = usage.WaterMeterPhoto;
        if (usage.ElectricityMeterPhoto !== undefined) bill.electricityMeterPhoto = usage.ElectricityMeterPhoto;

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
   *
   * 검침값이 틀리면(소수점 빠짐 등) 사용량이 수십~수천 배로 부풀어 금액이 numeric(10,2) 를 넘고
   * DB 가 500 을 냈다(2026-10, 9월분). 계산 전에 사용량을, 저장 전에 금액을 확인해 400 으로 알리고,
   * 저장은 전부 확인한 뒤 한 트랜잭션으로 한다(중간에 실패해 일부 호실만 바뀌지 않게).
   */
  async calculate(req: CalculateBillDto): Promise<Record<number, BillCalc>> {
    if (!(req.ElectricityTotalUsage > 0)) {
      throw new BadRequestException('전체 전기 사용량을 입력해주세요');
    }
    const costPerKWh = req.ElectricityTotalCost / req.ElectricityTotalUsage;

    const bills = await this.getByMonth(req.Month, req.BuildingId);
    const rooms = await this.roomsService.findByBuildingId(req.BuildingId);

    const roomMap = new Map<number, Room>(); // roomId -> Room
    const roomNoSpace = new Map<number, number>(); // roomNumber -> roomSpace
    const roomNoName = new Map<number, string>(); // roomNumber -> roomName (오류 메시지용)
    let totalSpace = 0;

    for (const room of rooms) {
      roomMap.set(room.roomId, room);
      if (!roomNoSpace.has(room.roomNumber)) {
        roomNoSpace.set(room.roomNumber, room.roomSpace);
        roomNoName.set(room.roomNumber, room.roomName);
        totalSpace += room.roomSpace;
      }
    }

    await this.assertElectricityUsage(req, bills, roomMap);

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
    }

    // 사용량 검사를 지나도 금액이 칸을 넘으면(±Infinity 포함) DB 가 500 을 내니 먼저 막는다.
    // NaN(수도 사용량 합 0)은 예전처럼 그대로 둔다 — 비교가 false 라 걸리지 않는다.
    for (const [roomNo, fBill] of fBillsMap) {
      const name = `${roomNo}호 ${roomNoName.get(roomNo) ?? ''}`.trim();
      if (Math.abs(fBill.electricityCostTotal) >= MAX_AMOUNT) {
        throw new BadRequestException(
          `${name} 전기요금이 ${won(fBill.electricityCostTotal)}으로 계산됐습니다. 검침값과 고지서 입력값을 확인해주세요.`,
        );
      }
      if (Math.abs(fBill.waterCostTotal) >= MAX_AMOUNT) {
        throw new BadRequestException(
          `${name} 수도요금이 ${won(fBill.waterCostTotal)}으로 계산됐습니다. 검침값과 고지서 입력값을 확인해주세요.`,
        );
      }
    }

    await this.billsRepo.manager.transaction(async (em) => {
      for (const [roomNo, fBill] of fBillsMap) {
        const separateBill = billMap.get(roomNo);
        if (!separateBill) continue;
        await em.update(
          Bill,
          { billId: separateBill.billId },
          { electricityBill: fBill.electricityCostTotal, waterBill: fBill.waterCostTotal },
        );
      }
    });

    const result: Record<number, BillCalc> = {};
    for (const [roomNo, fBill] of fBillsMap) result[roomNo] = fBill;
    return result;
  }

  /**
   * 호실 전기 사용량 합이 건물 전체(한전 고지서) 사용량보다 터무니없이 크면 검침 오류다 —
   * 그대로 계산하면 공용요금이 큰 음수가 되어 호실마다 수억 원의 ± 금액이 나온다.
   * 지난달보다 크게 늘어난 호실(없으면 사용량이 큰 호실)을 짚어 400 으로 알린다.
   */
  private async assertElectricityUsage(req: CalculateBillDto, bills: Bill[], roomMap: Map<number, Room>) {
    const counted = bills.filter((b) => roomMap.has(b.roomId));
    const sum = counted.reduce((s, b) => s + b.electricityUsage, 0);
    if (sum <= req.ElectricityTotalUsage * USAGE_SUM_TOLERANCE) return;

    const lastUsage = new Map<number, number>();
    for (const b of await this.getByMonth(prevMonth(req.Month), req.BuildingId)) lastUsage.set(b.roomId, b.electricityUsage);
    const ratio = (b: Bill) => b.electricityUsage / (lastUsage.get(b.roomId) ?? 0);

    const jumped = counted.filter((b) => (lastUsage.get(b.roomId) ?? 0) > 0 && ratio(b) > 2).sort((a, b) => ratio(b) - ratio(a));
    const suspects = jumped.length > 0 ? jumped : [...counted].sort((a, b) => b.electricityUsage - a.electricityUsage).slice(0, 3);
    const names = suspects
      .slice(0, MAX_SUSPECTS)
      .map((b) => {
        const room = roomMap.get(b.roomId)!;
        const last = lastUsage.get(b.roomId);
        return `${roomLabel(room)} ${kwh(b.electricityUsage)}${jumped.length > 0 ? `(지난달 ${kwh(last!)})` : ''}`;
      })
      .join(', ');
    const more = suspects.length > MAX_SUSPECTS ? ` 외 ${suspects.length - MAX_SUSPECTS}곳` : '';

    throw new BadRequestException(
      `호실 전기 사용량 합계(${kwh(sum)})가 건물 전체 사용량(${kwh(req.ElectricityTotalUsage)})보다 훨씬 큽니다. ` +
        `${jumped.length > 0 ? '지난달보다 크게 늘어난 호실' : '사용량이 큰 호실'}: ${names}${more}. ` +
        '검침 탭에서 지침값(소수점 빠짐 등)을 확인해주세요.',
    );
  }
}
