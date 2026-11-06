import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import * as path from 'path';
import { RoomsService } from '../rooms/rooms.service';
import { BuildingFeesService } from '../building-fees/building-fees.service';
import { ExcelBillDto } from './dto/excel-bill.dto';
import { formatKoreanMoney } from './bill-calc';

/** 양식에 박혀 있던 문구를 대신할 값(명세서 설정). 기존 값이면 출력이 예전과 똑같다. */
export interface TemplateText {
  managerTitle: string;
  payPlace: string;
  notice: string;
  meterDay: number;
  truncateUnit: number;
  /** notice 가 이 값과 같으면 양식 원문(공백 줄맞춤)을 그대로 둔다. */
  defaultNotice?: string;
}

export const LEGACY_TEMPLATE_TEXT: TemplateText = {
  managerTitle: '새아병원 관리사무소장',
  payPlace: '반여2동 우체국',
  notice: '',
  meterDay: 15,
  truncateUnit: 10,
};

/** 기존 양식 한 장(호실 하나)에 들어갈 값. values 키 = 양식 placeholder 이름(괄호 없이). */
export interface LegacySheetRow {
  name: string;
  area: number;
  chargeMonth?: string;
  values: Record<string, number>;
}

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

    // 3. 호실별 값 — 계산 식은 예전 그대로(Go: MakeBillExcel)
    const rows: LegacySheetRow[] = [];
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

      rows.push({
        name: room.roomName,
        area: room.roomSpace,
        chargeMonth: bill.ChargeMonth,
        values: {
          ElectricityCost: bill.ElectricityCost ?? 0,
          ElectricityCostCommon: bill.ElectricityCostCommon ?? 0,
          ElectricityCostTax: bill.ElectricityCostTax ?? 0,
          ElectricityCostFund: bill.ElectricityCostFund ?? 0,
          ElectricityCostTotal: bill.ElectricityCostTotal ?? 0,
          WaterCostSupply: bill.WaterCostSupply ?? 0,
          WaterCostSewer: bill.WaterCostSewer ?? 0,
          WaterCostCommon: bill.WaterCostCommon ?? 0,
          WaterCostTotal: bill.WaterCostTotal ?? 0,
          TotalCost: bill.TotalCost ?? 0,
          GeneralManagementFee: generalManagementFee,
          PublicInspectionFee: publicInspectionFee,
          FireManagementFee: fireManagementFee,
          ElevatorMaintenanceFee: elevatorMaintenanceFee,
          SepticTankManagementFee: septicTankManagementFee,
          ElectricalManagementFee: electricalManagementFee,
          ParkingManagementFee: parkingManagementFee,
          totalFeeWI,
          fireInsuranceFee,
          totalFee,
          lateFee,
          totalLateFee,
          ElectricityLateCost: electricityLateCost,
          WaterLateCost: waterLateCost,
          TotalLateCost: totalLateCost,
        },
      });
    }

    if (rows.length === 0) throw new NotFoundException('입력한 호실과 일치하는 방이 없습니다');
    return this.renderLegacyTemplate(rows, LEGACY_TEMPLATE_TEXT);
  }

  /**
   * 기존 명세서 양식(excel/bill.xlsx)으로 호실마다 시트를 만든다.
   * 금액은 truncateUnit(기본 10원) 아래를 버려 천 단위 콤마로 쓴다(Go: formatKoreanMoney).
   */
  async renderLegacyTemplate(rows: LegacySheetRow[], text: TemplateText): Promise<{ buffer: Buffer; filename: string }> {
    const wb = new ExcelJS.Workbook();
    try {
      await wb.xlsx.readFile(TEMPLATE_PATH);
    } catch {
      throw new InternalServerErrorException('엑셀 템플릿(excel/bill.xlsx)을 불러올 수 없습니다');
    }
    const template = wb.getWorksheet(TEMPLATE_SHEET);
    if (!template) throw new InternalServerErrorException(`템플릿 시트 '${TEMPLATE_SHEET}'가 없습니다`);

    // 레거시 Go 앱이 템플릿에 방 시트를 저장해둔 경우가 있어 'bill' 외 시트는 모두 제거한다.
    // (안 그러면 동일 이름 시트 추가 시 exceljs가 "Worksheet name already exists" 로 크래시)
    for (const sheet of [...wb.worksheets]) {
      if (sheet.id !== template.id) wb.removeWorksheet(sheet.id);
    }

    const usedNames = new Set<string>([TEMPLATE_SHEET]);
    for (const row of rows) {
      const replacements = this.buildReplacements(row, text);
      const sheetName = this.uniqueSheetName(wb, row.name, usedNames);
      this.cloneSheet(wb, template, sheetName, replacements, text);
    }

    // 템플릿 시트는 결과물에서 제거 (placeholder 노출 방지)
    wb.removeWorksheet(template.id);

    const buffer = Buffer.from((await wb.xlsx.writeBuffer()) as ArrayBuffer);
    const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    return { buffer, filename: `bills_${ts}.xlsx` };
  }

  /** 날짜/금액 placeholder → 실제 문자열 맵 구성. */
  private buildReplacements(row: LegacySheetRow, text: TemplateText): Record<string, string> {
    const pad = (n: number) => String(n).padStart(2, '0');

    // 사용월(charge_month) 기준. 고지서 규칙: "(month)월 고지서 = (lMonth)월 사용분".
    //  → (lMonth)=사용월, (month)=사용월+1.  charge_month 가 없으면 legacy(오늘 기준)로 폴백.
    let usageYear: number;
    let usageMonth0: number; // 0-based 사용월
    if (row.chargeMonth && /^\d{6}$/.test(row.chargeMonth)) {
      usageYear = parseInt(row.chargeMonth.slice(0, 4), 10);
      usageMonth0 = parseInt(row.chargeMonth.slice(4, 6), 10) - 1;
    } else {
      const now = new Date();
      usageYear = now.getFullYear();
      usageMonth0 = now.getMonth() - 1; // 사용월 = 지난달
    }

    const usage = new Date(usageYear, usageMonth0, 1); // 사용월
    const invoice = new Date(usageYear, usageMonth0 + 1, 1); // 고지서월 = 사용월 + 1
    const lastlast = new Date(usageYear, usageMonth0 - 1, 1); // 사용 전월

    const usageLastDay = new Date(usage.getFullYear(), usage.getMonth() + 1, 0).getDate();
    const invoiceLastDay = new Date(invoice.getFullYear(), invoice.getMonth() + 1, 0).getDate();
    const issueDay = Math.min(new Date().getDate(), invoiceLastDay); // 발행일 = 고지서월 + 오늘 일자

    const year = String(invoice.getFullYear());
    const month = pad(invoice.getMonth() + 1);
    const date = pad(issueDay);
    const lYear = String(usage.getFullYear());
    const lMonth = pad(usage.getMonth() + 1);
    const lastDayOfLastMonth = usageLastDay;
    const lastDayOfCurrentMonth = invoiceLastDay;
    const llYear = String(lastlast.getFullYear());
    const llMonth = pad(lastlast.getMonth() + 1);

    const unit = text.truncateUnit || 10;
    const m = (v: number) => (unit === 10 ? formatKoreanMoney(v) : Math.trunc(Math.floor(v / unit) * unit).toLocaleString('en-US'));
    const out: Record<string, string> = {
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
      '(name)': row.name,
      '(area)': row.area.toFixed(2),
    };
    for (const [k, v] of Object.entries(row.values)) out[`(${k})`] = m(v);
    return out;
  }

  /** 템플릿 시트를 새 시트로 복제(값/스타일/병합/크기)하며 placeholder 치환. */
  private cloneSheet(
    wb: ExcelJS.Workbook,
    template: ExcelJS.Worksheet,
    name: string,
    replacements: Record<string, string>,
    text: TemplateText,
  ): void {
    // 양식에 박혀 있던 문구 → 설정값(기존 값이면 그대로라 출력이 같다)
    const fixed: Record<string, string> = {
      '새아병원 관리사무소장': text.managerTitle,
      '반여2동 우체국': text.payPlace,
      '전기 15일, 수도 15일': `전기 ${text.meterDay}일, 수도 ${text.meterDay}일`,
      '(llMonth).15': `(llMonth).${String(text.meterDay).padStart(2, '0')}`,
      '(lMonth).15': `(lMonth).${String(text.meterDay).padStart(2, '0')}`,
    };
    const useCustomNotice = !!text.notice && text.notice !== text.defaultNotice;
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
        let v: ExcelJS.CellValue = cell.value;
        if (useCustomNotice && typeof v === 'string' && v.startsWith('☞ 입점주')) v = text.notice;
        if (text.meterDay !== 15 || text.managerTitle !== LEGACY_TEMPLATE_TEXT.managerTitle || text.payPlace !== LEGACY_TEMPLATE_TEXT.payPlace) {
          v = this.replaceValue(v, fixed);
        }
        newCell.value = this.replaceValue(v, replacements);
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

  /** 엑셀 시트명 제약(31자, 특수문자 금지, 워크북 내 중복 금지) 처리. */
  private uniqueSheetName(wb: ExcelJS.Workbook, raw: string, used: Set<string>): string {
    const base = (raw || 'sheet').replace(/[\\/?*[\]:]/g, ' ').trim().slice(0, 28) || 'sheet';
    let name = base;
    let i = 1;
    // used(이번 실행 추가분) + 워크북에 이미 존재하는 시트 모두 회피
    while (used.has(name) || wb.getWorksheet(name)) {
      name = `${base.slice(0, 25)}_${i++}`;
    }
    used.add(name);
    return name;
  }
}
