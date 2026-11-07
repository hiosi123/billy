import { Injectable, NotFoundException } from '@nestjs/common';
import * as ExcelJS from 'exceljs';
import { DataSource } from 'typeorm';
import { ExcelService, LegacySheetRow } from '../bills/excel.service';
import { EngineGroupTotal, EngineLine } from './engine/types';
import { MonthsService } from './months.service';
import { LEGACY_STATEMENT_SETTINGS, SettingsService } from './settings.service';
import { StatementSettings } from './entities/building-setting.entity';

type StatementView = Awaited<ReturnType<MonthsService['statements']>>[number];

/** 기존 양식 칸에 들어가는 항목 코드(legacy-v1). 이 코드만으로 된 명세서는 기존 양식으로 낸다. */
const LEGACY_FEE_CODES = ['general', 'inspection', 'fire_mgmt', 'elevator', 'septic', 'elec_mgmt', 'parking'];
const LEGACY_CODES = new Set([
  ...LEGACY_FEE_CODES,
  'fire_insurance',
  'elec_usage',
  'elec_common',
  'elec_vat',
  'elec_fund',
  'tv',
  'water_supply',
  'water_sewer',
  'water_common',
]);

/** 확정 명세서 → 엑셀. 금액은 확정 때 저장한 값 그대로(다시 계산하지 않는다). */
@Injectable()
export class StatementExcelService {
  constructor(
    private readonly months: MonthsService,
    private readonly settings: SettingsService,
    private readonly excel: ExcelService,
    private readonly dataSource: DataSource,
  ) {}

  async build(buildingId: number, month: string): Promise<{ buffer: Buffer; filename: string }> {
    const statements = await this.months.statements(buildingId, month);
    if (statements.length === 0) throw new NotFoundException('확정된 명세서가 없습니다. 먼저 확정해주세요');
    const settings = await this.settings.get(buildingId);
    const legacy = statements.every((s) => isLegacyCompatible(s.lines, s.groups));
    const { buffer } = legacy
      ? await this.excel.renderLegacyTemplate(
          statements.map((s) => toLegacyRow(s, settings.lateFeeRate ?? 0.02)),
          {
            managerTitle: settings.managerTitle ?? '',
            payPlace: settings.payPlace ?? '',
            notice: settings.notice ?? '',
            meterDay: settings.meterDay ?? 15,
            truncateUnit: settings.truncateUnit ?? 10,
            defaultNotice: LEGACY_STATEMENT_SETTINGS.notice,
          },
        )
      : await this.generic(buildingId, month, statements, settings);
    return { buffer, filename: `billy_${month}.xlsx` };
  }

  /** 항목을 바꾼 건물용 명세서 — 호실마다 시트(묶음별 항목·소계·합계·납부 안내) + 전체 요약. */
  private async generic(buildingId: number, month: string, statements: StatementView[], s: StatementSettings): Promise<{ buffer: Buffer }> {
    const b = await this.dataSource.query('SELECT building_name FROM buildings WHERE building_id = $1', [buildingId]);
    const buildingName = b[0]?.building_name ?? '';
    const unit = s.truncateUnit ?? 1;
    const money = (v: number) => Math.floor(v / unit) * unit;
    const title = `${month.slice(0, 4)}년 ${Number(month.slice(4, 6))}월 관리비 명세서`;
    const due = dueDate(month, s.dueDay);
    const wb = new ExcelJS.Workbook();
    const used = new Set<string>();

    const summary = wb.addWorksheet('전체');
    const groupLabels = statements[0].groups.map((g: EngineGroupTotal) => g.label);
    summary.addRow([`${buildingName} ${title}`]).font = { bold: true, size: 14 };
    summary.addRow([]);
    const head = summary.addRow(['호실', '이름', ...groupLabels, '합계', '입금액', '남은 금액']);
    head.font = { bold: true };
    for (const st of statements) {
      summary.addRow([
        `${st.unitNumber}호`,
        st.unitName,
        ...st.groups.map((g: EngineGroupTotal) => money(g.amount)),
        money(st.total),
        st.paidAmount,
        Math.max(money(st.total) - st.paidAmount, 0),
      ]);
    }
    summary.columns.forEach((c, i) => (c.width = i < 2 ? 14 : 14));
    summary.eachRow((row, n) => {
      if (n > 3) row.eachCell((cell, col) => col > 2 && (cell.numFmt = '#,##0'));
    });

    for (const st of statements) {
      let name = `${st.unitNumber}호 ${st.unitName}`.replace(/[\\/?*[\]:]/g, ' ').trim().slice(0, 28) || `${st.unitNumber}`;
      for (let i = 2; used.has(name); i++) name = `${name.slice(0, 25)}_${i}`;
      used.add(name);
      const ws = wb.addWorksheet(name, { pageSetup: { paperSize: 9, orientation: 'portrait', fitToPage: true, fitToWidth: 1 } });
      ws.columns = [{ width: 16 }, { width: 26 }, { width: 18 }];
      ws.addRow([`${buildingName} ${title}`]).font = { bold: true, size: 15 };
      ws.addRow([`${st.unitNumber}호 ${st.unitName}`, `면적 ${st.area.toFixed(2)}㎡`]).font = { bold: true };
      ws.addRow([]);
      const h = ws.addRow(['구분', '항목', '금액(원)']);
      h.font = { bold: true };
      h.eachCell((c) => (c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFF3FB' } }));
      for (const g of st.groups as EngineGroupTotal[]) {
        const lines = (st.lines as EngineLine[]).filter((l) => l.group === g.group && !l.hidden);
        lines.forEach((l, i) => ws.addRow([i === 0 ? g.label : '', l.label, money(l.amount)]));
        const sub = ws.addRow(['', `${g.label} 소계`, money(g.amount)]);
        sub.font = { bold: true };
      }
      const total = ws.addRow(['합계', '', money(st.total)]);
      total.font = { bold: true, size: 13 };
      ws.addRow([]);
      ws.addRow(['납부 기한', due]);
      if (s.payPlace) ws.addRow(['납부 장소', s.payPlace]);
      if (s.bankAccount) ws.addRow(['입금 계좌', s.bankAccount]);
      if ((s.lateFeeRate ?? 0) > 0) ws.addRow(['납기 후 금액', '', money(st.total * (1 + (s.lateFeeRate ?? 0)))]);
      if (s.notice) {
        ws.addRow([]);
        const r = ws.addRow([s.notice]);
        ws.mergeCells(`A${r.number}:C${r.number}`);
        r.getCell(1).alignment = { wrapText: true, vertical: 'top' };
        r.height = 60;
      }
      if (s.managerTitle) ws.addRow(['', '', s.managerTitle]).font = { bold: true };
      ws.eachRow((row) => row.getCell(3).numFmt !== undefined && typeof row.getCell(3).value === 'number' && (row.getCell(3).numFmt = '#,##0'));
    }
    const buffer = Buffer.from((await wb.xlsx.writeBuffer()) as ArrayBuffer);
    return { buffer };
  }
}

export function isLegacyCompatible(lines: EngineLine[], groups: EngineGroupTotal[]): boolean {
  const codes = new Set(lines.map((l) => l.code));
  for (const c of codes) if (!LEGACY_CODES.has(c)) return false;
  for (const c of [...LEGACY_FEE_CODES, 'elec_usage', 'elec_common', 'elec_vat', 'elec_fund', 'water_supply', 'water_sewer', 'water_common']) {
    if (!codes.has(c)) return false;
  }
  const g = new Set(groups.map((x) => x.group));
  return g.has('fee') && g.has('electricity') && g.has('water');
}

/** 확정 명세서 → 기존 양식 값. 계산 식은 기존 엑셀(excel.service makeBillExcel)과 같다. */
export function toLegacyRow(st: StatementView, lateRate: number): LegacySheetRow {
  const lines = st.lines as EngineLine[];
  const raw = (c: string) => lines.find((l) => l.code === c)?.raw ?? 0;
  const amount = (c: string) => lines.find((l) => l.code === c)?.amount ?? 0;
  const group = (g: string) => (st.groups as EngineGroupTotal[]).find((x) => x.group === g)!;
  const fee = LEGACY_FEE_CODES.map(raw);
  const totalFeeWI = fee[0] + fee[1] + fee[2] + fee[3] + fee[4] + fee[5] + fee[6];
  const totalFee = group('fee').raw;
  const lateFee = totalFee * lateRate;
  const eTotal = group('electricity').amount;
  const wTotal = group('water').amount;
  const totalCost = Math.round(group('electricity').raw + group('water').raw);
  const eLate = eTotal * lateRate;
  const wLate = wTotal * lateRate;
  return {
    name: st.unitName,
    area: st.area,
    chargeMonth: st.chargeMonth,
    values: {
      GeneralManagementFee: fee[0],
      PublicInspectionFee: fee[1],
      FireManagementFee: fee[2],
      ElevatorMaintenanceFee: fee[3],
      SepticTankManagementFee: fee[4],
      ElectricalManagementFee: fee[5],
      ParkingManagementFee: fee[6],
      totalFeeWI,
      fireInsuranceFee: raw('fire_insurance'),
      totalFee,
      lateFee,
      totalLateFee: totalFee + lateFee,
      ElectricityCost: amount('elec_usage'),
      ElectricityCostCommon: amount('elec_common'),
      ElectricityCostTax: amount('elec_vat'),
      ElectricityCostFund: amount('elec_fund'),
      ElectricityCostTotal: eTotal,
      WaterCostSupply: amount('water_supply'),
      WaterCostSewer: amount('water_sewer'),
      WaterCostCommon: amount('water_common'),
      WaterCostTotal: wTotal,
      TotalCost: totalCost,
      ElectricityLateCost: eLate,
      WaterLateCost: wLate,
      TotalLateCost: eLate + wLate + totalCost,
    },
  };
}

/** 납부 기한: dueDay 가 있으면 고지월의 그날, 없으면 고지월 말일(기존 양식: 사용월 다음 달 말일). */
export function dueDate(month: string, dueDay?: number): string {
  const y = parseInt(month.slice(0, 4), 10);
  const m = parseInt(month.slice(4, 6), 10); // 사용월
  const invoiceLast = new Date(Date.UTC(y, m + 1, 0)).getUTCDate(); // 고지월(사용월+1) 말일
  const day = Math.min(dueDay ?? invoiceLast, invoiceLast);
  const inv = new Date(Date.UTC(y, m, 1));
  return `${inv.getUTCFullYear()}-${String(inv.getUTCMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}
