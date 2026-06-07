import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import * as path from 'path';
import { RoomsService } from '../rooms/rooms.service';
import { BuildingFeesService } from '../building-fees/building-fees.service';
import { ExcelBillDto } from './dto/excel-bill.dto';
import { formatKoreanMoney } from './bill-calc';

const TEMPLATE_PATH = path.join(process.cwd(), 'excel', 'bill.xlsx');
const TEMPLATE_SHEET = 'bill';

@Injectable()
export class ExcelService {
  constructor(
    private roomsService: RoomsService,
    private buildingFeesService: BuildingFeesService,
  ) {}

  /**
   * 호실별 관리비 명세서 엑셀 생성. (Go: MakeBillExcel)
   * 템플릿 시트의 (placeholder) 들을 실제 값으로 치환해 호실마다 시트를 만든다.
   */
  async makeBillExcel(bills: ExcelBillDto[]): Promise<{ buffer: Buffer; filename: string }> {
    if (!bills || bills.length === 0) {
      throw new NotFoundException('생성할 청구 데이터가 없습니다');
    }
    const buildingId = bills[0].BuildingId;

    // 1. 건물의 모든 호실 + 전체 면적
    const rooms = await this.roomsService.findByBuildingId(buildingId);
    const roomNumberMap = new Map<number, (typeof rooms)[number]>();
    let totalSpace = 0;
    for (const room of rooms) {
      if (!roomNumberMap.has(room.roomNumber)) {
        roomNumberMap.set(room.roomNumber, room);
        totalSpace += room.roomSpace;
      }
    }

    // 2. 건물 고정 관리비
    const fee = await this.buildingFeesService.findByBuildingId(buildingId);

    // 3. 템플릿 로드
    const wb = new ExcelJS.Workbook();
    try {
      await wb.xlsx.readFile(TEMPLATE_PATH);
    } catch {
      throw new InternalServerErrorException('엑셀 템플릿(excel/bill.xlsx)을 불러올 수 없습니다');
    }
    const template = wb.getWorksheet(TEMPLATE_SHEET);
    if (!template) throw new InternalServerErrorException(`템플릿 시트 '${TEMPLATE_SHEET}'가 없습니다`);

    const usedNames = new Set<string>();
    let created = 0;

    for (const bill of bills) {
      const room = roomNumberMap.get(bill.RoomNumber);
      if (!room) continue;

      // 면적 비례 관리비 안분
      const ratio = totalSpace > 0 ? room.roomSpace / totalSpace : 0;
      const generalManagementFee = fee.generalManagementFee * ratio;
      const publicInspectionFee = fee.publicInspectionFee * ratio;
      const fireManagementFee = fee.fireManagementFee * ratio;
      const elevatorMaintenanceFee = fee.elevatorMaintenanceFee * ratio;
      const septicTankManagementFee = fee.septicTankManagementFee * ratio;
      const electricalManagementFee = fee.electricalManagementFee * ratio;
      const parkingManagementFee = fee.parkingManagementFee * ratio;

      const totalFeeWI =
        generalManagementFee +
        publicInspectionFee +
        fireManagementFee +
        elevatorMaintenanceFee +
        septicTankManagementFee +
        electricalManagementFee +
        parkingManagementFee;
      const fireInsuranceFee = room.roomBaseCost;
      const totalFee = totalFeeWI + room.roomBaseCost;
      const lateFee = totalFee * 0.02;
      const totalLateFee = totalFee + lateFee;
      const electricityLateCost = (bill.ElectricityCostTotal ?? 0) * 0.02;
      const waterLateCost = (bill.WaterCostTotal ?? 0) * 0.02;
      const totalLateCost = electricityLateCost + waterLateCost + (bill.TotalCost ?? 0);

      const replacements = this.buildReplacements(room.roomName, room.roomSpace, bill, {
        generalManagementFee,
        publicInspectionFee,
        fireManagementFee,
        elevatorMaintenanceFee,
        septicTankManagementFee,
        electricalManagementFee,
        parkingManagementFee,
        totalFeeWI,
        fireInsuranceFee,
        totalFee,
        lateFee,
        totalLateFee,
        electricityLateCost,
        waterLateCost,
        totalLateCost,
      });

      const sheetName = this.uniqueSheetName(room.roomName, usedNames);
      this.cloneSheet(wb, template, sheetName, replacements);
      created++;
    }

    if (created === 0) throw new NotFoundException('입력한 호실과 일치하는 방이 없습니다');

    // 템플릿 시트는 결과물에서 제거 (placeholder 노출 방지)
    wb.removeWorksheet(template.id);

    const buffer = Buffer.from((await wb.xlsx.writeBuffer()) as ArrayBuffer);
    const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    return { buffer, filename: `bills_${ts}.xlsx` };
  }

  /** 날짜/금액 placeholder → 실제 문자열 맵 구성. */
  private buildReplacements(
    roomName: string,
    roomSpace: number,
    bill: ExcelBillDto,
    fees: Record<string, number>,
  ): Record<string, string> {
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');

    const year = String(now.getFullYear());
    const month = pad(now.getMonth() + 1);
    const date = pad(now.getDate());

    const last = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const lYear = String(last.getFullYear());
    const lMonth = pad(last.getMonth() + 1);

    const lastDayOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0).getDate();
    const lastDayOfCurrentMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();

    const lastlast = new Date(now.getFullYear(), now.getMonth() - 2, 1);
    const llYear = String(lastlast.getFullYear());
    const llMonth = pad(lastlast.getMonth() + 1);

    const m = formatKoreanMoney;
    return {
      '(year)': year,
      '(month)': month,
      '(date)': date,
      '(lYear)': lYear,
      '(lMonth)': lMonth,
      '(fDate)': '01',
      '(lDate)': pad(lastDayOfLastMonth),
      '(tDate)': pad(lastDayOfCurrentMonth),
      '(llYear)': llYear,
      '(llMonth)': llMonth,
      '(name)': roomName,
      '(area)': roomSpace.toFixed(2),
      '(ElectricityCost)': m(bill.ElectricityCost ?? 0),
      '(ElectricityCostCommon)': m(bill.ElectricityCostCommon ?? 0),
      '(ElectricityCostTax)': m(bill.ElectricityCostTax ?? 0),
      '(ElectricityCostFund)': m(bill.ElectricityCostFund ?? 0),
      '(ElectricityCostTotal)': m(bill.ElectricityCostTotal ?? 0),
      '(WaterCostSupply)': m(bill.WaterCostSupply ?? 0),
      '(WaterCostSewer)': m(bill.WaterCostSewer ?? 0),
      '(WaterCostCommon)': m(bill.WaterCostCommon ?? 0),
      '(WaterCostTotal)': m(bill.WaterCostTotal ?? 0),
      '(TotalCost)': m(bill.TotalCost ?? 0),
      '(GeneralManagementFee)': m(fees.generalManagementFee),
      '(PublicInspectionFee)': m(fees.publicInspectionFee),
      '(FireManagementFee)': m(fees.fireManagementFee),
      '(ElevatorMaintenanceFee)': m(fees.elevatorMaintenanceFee),
      '(SepticTankManagementFee)': m(fees.septicTankManagementFee),
      '(ElectricalManagementFee)': m(fees.electricalManagementFee),
      '(ParkingManagementFee)': m(fees.parkingManagementFee),
      '(totalFeeWI)': m(fees.totalFeeWI),
      '(fireInsuranceFee)': m(fees.fireInsuranceFee),
      '(totalFee)': m(fees.totalFee),
      '(lateFee)': m(fees.lateFee),
      '(totalLateFee)': m(fees.totalLateFee),
      '(ElectricityLateCost)': m(fees.electricityLateCost),
      '(WaterLateCost)': m(fees.waterLateCost),
      '(TotalLateCost)': m(fees.totalLateCost),
    };
  }

  /** 템플릿 시트를 새 시트로 복제(값/스타일/병합/크기)하며 placeholder 치환. */
  private cloneSheet(
    wb: ExcelJS.Workbook,
    template: ExcelJS.Worksheet,
    name: string,
    replacements: Record<string, string>,
  ): void {
    const ws = wb.addWorksheet(name, {
      pageSetup: {
        orientation: 'landscape',
        paperSize: 9, // A4
        fitToPage: true,
        fitToWidth: 1,
        fitToHeight: 1,
        margins: { top: 0.3, bottom: 0.3, left: 0.25, right: 0.25, header: 0.2, footer: 0.2 },
      },
    });

    // 열 너비
    template.columns?.forEach((col, i) => {
      if (col.width) ws.getColumn(i + 1).width = col.width;
    });

    // 행/셀 값 + 스타일
    template.eachRow({ includeEmpty: true }, (row, rowNumber) => {
      const newRow = ws.getRow(rowNumber);
      if (row.height) newRow.height = row.height;
      row.eachCell({ includeEmpty: true }, (cell, colNumber) => {
        const newCell = newRow.getCell(colNumber);
        newCell.value = this.replaceValue(cell.value, replacements);
        if (cell.style) newCell.style = JSON.parse(JSON.stringify(cell.style));
      });
      newRow.commit();
    });

    // 병합 셀
    const merges: string[] = (template.model as any)?.merges ?? [];
    for (const range of merges) {
      try {
        ws.mergeCells(range);
      } catch {
        /* 병합 충돌 무시 */
      }
    }
  }

  /** 셀 값(문자열/리치텍스트) 내 placeholder 치환. */
  private replaceValue(value: ExcelJS.CellValue, replacements: Record<string, string>): ExcelJS.CellValue {
    const apply = (s: string): string => {
      let out = s;
      for (const [k, v] of Object.entries(replacements)) {
        if (out.includes(k)) out = out.split(k).join(v);
      }
      return out;
    };

    if (typeof value === 'string') return apply(value);
    if (value && typeof value === 'object' && 'richText' in (value as any)) {
      const rt = (value as ExcelJS.CellRichTextValue).richText.map((run) => ({ ...run, text: apply(run.text) }));
      return { richText: rt };
    }
    return value;
  }

  /** 엑셀 시트명 제약(31자, 특수문자 금지, 중복 금지) 처리. */
  private uniqueSheetName(raw: string, used: Set<string>): string {
    let base = (raw || 'sheet').replace(/[\\/?*[\]:]/g, ' ').trim().slice(0, 28) || 'sheet';
    let name = base;
    let i = 1;
    while (used.has(name)) {
      name = `${base.slice(0, 25)}_${i++}`;
    }
    used.add(name);
    return name;
  }
}
