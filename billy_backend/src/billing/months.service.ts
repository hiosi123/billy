import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { computePlan, PlanError } from './engine/engine';
import { ChargePlanDef, EngineInput, EngineResult, Utility } from './engine/types';
import { INPUT_LABELS, requiredInputs } from './presets';
import { PlansService } from './plans.service';
import { UnitsService } from './units.service';

export interface Issue {
  level: 'error' | 'warning';
  message: string;
}

/** 기존 calc_inputs 칸 ↔ 입력 키(고지서 사진 인식이 채우는 칸과 이어진다). */
const LEGACY_COLUMNS: Record<string, string> = {
  E_COST: 'electricity_total_cost',
  E_USAGE: 'electricity_total_usage',
  W_TOTAL: 'water_total_cost',
  W_USAGE: 'water_total_usage',
  W_SUPPLY: 'water_supply_cost',
  W_SEWER: 'water_sewer_cost',
};

const MONTH_RE = /^\d{6}$/;
/** 호실 사용량 합이 고지서 사용량의 이 배수를 넘으면 검침 오류(2026-10 9월분 소수점 빠짐 사고 규칙 그대로). */
const USAGE_SUM_TOLERANCE = 1.3;
const MAX_TOTAL = 1e12; // statements.total numeric(14,2)

const num = (v: unknown) => (v === null || v === undefined ? 0 : parseFloat(String(v)) || 0);
const won = (n: number) => `${Math.round(n).toLocaleString('ko-KR')}원`;
const fmtUsage = (n: number, u: Utility) => `${n.toLocaleString('ko-KR', { maximumFractionDigits: 2 })}${u === 'water' ? '㎥' : 'kWh'}`;

export function prevMonth(yyyymm: string): string {
  const y = parseInt(yyyymm.slice(0, 4), 10);
  const m = parseInt(yyyymm.slice(4, 6), 10);
  const d = new Date(Date.UTC(y, m - 2, 1));
  return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

function assertMonth(month: string) {
  if (!MONTH_RE.test(month ?? '')) throw new BadRequestException('월은 YYYYMM 형식이어야 합니다');
}

/**
 * 월 마감 흐름: 입력 저장 → 미리보기(쓰기 없음) → 확정(명세서 스냅샷) → 명세서·입금.
 * 금액은 늘 서버가 계산한다 — 화면이 보낸 금액을 저장하지 않는다.
 */
@Injectable()
export class MonthsService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly units: UnitsService,
    private readonly plans: PlansService,
  ) {}

  // ── 입력값 ──────────────────────────────────────────────

  async getInputs(buildingId: number, month: string) {
    assertMonth(month);
    const ci = await this.dataSource.query('SELECT * FROM calc_inputs WHERE building_id = $1 AND charge_month = $2', [buildingId, month]);
    const mi = await this.dataSource.query('SELECT inputs FROM month_inputs WHERE building_id = $1 AND charge_month = $2', [buildingId, month]);
    const values: Record<string, number> = {};
    for (const [k, v] of Object.entries((mi[0]?.inputs ?? {}) as Record<string, unknown>)) {
      const n = Number(v);
      if (Number.isFinite(n)) values[k] = n;
    }
    if (ci.length) {
      for (const [key, col] of Object.entries(LEGACY_COLUMNS)) values[key] = num(ci[0][col]);
    }
    let elecPhotos: string[] = [];
    try {
      const parsed = ci[0]?.elec_photos ? JSON.parse(ci[0].elec_photos) : [];
      if (Array.isArray(parsed)) elecPhotos = parsed.filter((s) => typeof s === 'string' && s);
    } catch {
      elecPhotos = [];
    }
    return { values, saved: ci.length > 0 || mi.length > 0, photos: { water: ci[0]?.water_photo ?? null, electricity: elecPhotos } };
  }

  /**
   * 입력값 저장. 기존 6칸은 calc_inputs(사진은 그대로 둔다), 나머지는 month_inputs 에 합친다.
   * photos 를 주면 사진 URL 도 갱신한다.
   */
  async saveInputs(buildingId: number, month: string, values: Record<string, unknown>, photos?: { water?: string | null; electricity?: string[] }) {
    assertMonth(month);
    const legacy: Record<string, number> = {};
    const extra: Record<string, number> = {};
    for (const [k, v] of Object.entries(values ?? {})) {
      if (!/^[A-Za-z0-9_:.-]{1,60}$/.test(k)) throw new BadRequestException(`입력 키 '${k}' 가 올바르지 않습니다`);
      const n = v === null || v === '' ? 0 : Number(v);
      if (!Number.isFinite(n)) throw new BadRequestException(`'${INPUT_LABELS[k]?.label ?? k}' 값이 숫자가 아닙니다`);
      if (LEGACY_COLUMNS[k]) legacy[k] = n;
      else extra[k] = n;
    }
    await this.dataSource.transaction(async (em) => {
      if (Object.keys(legacy).length || photos) {
        const cols = Object.keys(legacy).map((k) => LEGACY_COLUMNS[k]);
        const vals = Object.keys(legacy).map((k) => legacy[k]);
        const insertCols = ['building_id', 'charge_month', ...cols];
        const params: unknown[] = [buildingId, month, ...vals];
        const updates = cols.map((c) => `${c} = EXCLUDED.${c}`);
        if (photos?.water !== undefined) {
          insertCols.push('water_photo');
          params.push(photos.water);
          updates.push('water_photo = EXCLUDED.water_photo');
        }
        if (photos?.electricity !== undefined) {
          insertCols.push('elec_photos');
          params.push(photos.electricity.length ? JSON.stringify(photos.electricity) : null);
          updates.push('elec_photos = EXCLUDED.elec_photos');
        }
        updates.push('updated_at = now()');
        await em.query(
          `INSERT INTO calc_inputs (${insertCols.join(', ')}) VALUES (${insertCols.map((_, i) => `$${i + 1}`).join(', ')})
           ON CONFLICT (building_id, charge_month) DO UPDATE SET ${updates.join(', ')}`,
          params,
        );
      }
      if (Object.keys(extra).length) {
        await em.query(
          `INSERT INTO month_inputs (building_id, charge_month, inputs) VALUES ($1, $2, $3)
           ON CONFLICT (building_id, charge_month) DO UPDATE SET inputs = month_inputs.inputs || EXCLUDED.inputs, updated_at = now()`,
          [buildingId, month, JSON.stringify(extra)],
        );
      }
    });
    return this.getInputs(buildingId, month);
  }

  // ── 계산 ────────────────────────────────────────────────

  /** 엔진 입력: 호실(대표 계량기 순서) + 그달 계량기 사용량(bill_id 순서) + 입력값. */
  async engineInput(buildingId: number, month: string, overrideInputs?: Record<string, number>): Promise<EngineInput> {
    const units = await this.units.engineUnits(buildingId);
    const rows = await this.dataSource.query(
      `SELECT um.unit_id, b.electricity_usage, b.water_usage
       FROM bills b JOIN unit_meters um ON um.room_id = b.room_id
       WHERE b.building_id = $1 AND b.charge_month = $2
       ORDER BY b.bill_id`,
      [buildingId, month],
    );
    const { values } = await this.getInputs(buildingId, month);
    return {
      units,
      meters: rows.map((r: any) => ({ unitId: Number(r.unit_id), electricity: num(r.electricity_usage), water: num(r.water_usage) })),
      inputs: { ...values, ...(overrideInputs ?? {}) },
    };
  }

  /** 미리보기 — 아무것도 쓰지 않는다. definition 을 주면 저장 안 한 요금표로 계산(설정 화면의 '지난달에 적용하면'). */
  async preview(buildingId: number, month: string, opts: { definition?: ChargePlanDef; inputs?: Record<string, number> } = {}) {
    assertMonth(month);
    const eff = opts.definition ? { definition: opts.definition, effectiveFrom: null, source: 'draft' as const } : await this.plans.effective(buildingId, month);
    const plan = eff.definition;
    const input = await this.engineInput(buildingId, month, opts.inputs);
    const issues: Issue[] = [];

    // 필요한 입력
    const required = requiredInputs(plan).map((key) => ({
      key,
      label: INPUT_LABELS[key]?.label ?? key,
      unit: INPUT_LABELS[key]?.unit ?? '',
      value: input.inputs[key] ?? null,
    }));
    for (const r of required) {
      if (r.value === null || r.value === 0) {
        const isUsage = plan.items.some((i) => i.method === 'UNIT_PRICE' && i.usageInput === r.key);
        issues.push({ level: isUsage ? 'error' : 'warning', message: `${r.label}${isUsage ? '을(를) 입력해주세요' : '이(가) 0입니다'}` });
      }
    }

    // 검침
    const readings = await this.readings(buildingId, month);
    if (readings.missing.length && readings.entered > 0) {
      issues.push({
        level: 'warning',
        message: `이번 달 검침이 없는 계량기 ${readings.missing.length}개: ${readings.missing.slice(0, 5).join(', ')}${readings.missing.length > 5 ? ' 외' : ''}`,
      });
    }
    if (readings.entered === 0) issues.push({ level: 'error', message: '이번 달 검침이 하나도 없습니다. 검침부터 입력해주세요' });

    // 사용량 검산(호실 합계 vs 고지서 사용량)
    issues.push(...(await this.usageChecks(buildingId, month, plan, input)));

    let result: EngineResult | null = null;
    if (!issues.some((i) => i.level === 'error')) {
      try {
        result = computePlan(plan, input);
        for (const w of result.warnings) issues.push({ level: 'warning', message: w });
        const over = result.units.find((u) => Math.abs(u.total.amount) >= MAX_TOTAL || !Number.isFinite(u.total.amount));
        if (over) {
          issues.push({ level: 'error', message: `${over.unitNumber}호 합계가 ${won(over.total.amount)}으로 계산됐습니다. 검침값과 고지서 입력값을 확인해주세요` });
          result = null;
        }
      } catch (e) {
        if (e instanceof PlanError) issues.push({ level: 'error', message: e.message });
        else throw e;
      }
    }

    // 지난달 확정 금액과 비교
    const last = await this.dataSource.query('SELECT unit_number, total FROM statements WHERE building_id = $1 AND charge_month = $2', [buildingId, prevMonth(month)]);
    const compare: Record<string, number> = {};
    for (const r of last) compare[String(r.unit_number)] = num(r.total);

    const issued = await this.dataSource.query(
      'SELECT COUNT(*)::int AS n, MAX(issued_at) AS at FROM statements WHERE building_id = $1 AND charge_month = $2',
      [buildingId, month],
    );

    return {
      month,
      plan: { source: eff.source, effectiveFrom: eff.effectiveFrom, preset: plan.preset ?? null, roundingMode: plan.roundingMode, groups: plan.groups },
      inputs: { required },
      readings,
      result,
      issues,
      compare,
      issued: { count: issued[0]?.n ?? 0, issuedAt: issued[0]?.at ?? null },
    };
  }

  /** 그달 검침 현황: 계량기 행 전체 대비 bill 이 있는 행. */
  async readings(buildingId: number, month: string) {
    const rows = await this.dataSource.query(
      `SELECT r.room_id, COALESCE(NULLIF(r.measure_machine, ''), r.room_name) AS label,
              EXISTS (SELECT 1 FROM bills b WHERE b.room_id = r.room_id AND b.charge_month = $2) AS has_bill
       FROM rooms r WHERE r.building_id = $1 ORDER BY r.room_id`,
      [buildingId, month],
    );
    return {
      total: rows.length,
      entered: rows.filter((r: any) => r.has_bill).length,
      missing: rows.filter((r: any) => !r.has_bill).map((r: any) => String(r.label)),
    };
  }

  /** 호실 사용량 합이 고지서 사용량보다 터무니없이 크면 오류 — 지난달보다 크게 늘어난 호실을 짚는다. */
  private async usageChecks(buildingId: number, month: string, plan: ChargePlanDef, input: EngineInput): Promise<Issue[]> {
    const issues: Issue[] = [];
    const checks: { utility: Utility; key: string }[] = [];
    const ePrice = plan.items.find((i) => i.method === 'UNIT_PRICE' && i.utility === 'electricity');
    if (ePrice?.usageInput) checks.push({ utility: 'electricity', key: ePrice.usageInput });
    const wPrice = plan.items.find((i) => i.method === 'UNIT_PRICE' && i.utility === 'water');
    if (wPrice?.usageInput) checks.push({ utility: 'water', key: wPrice.usageInput });
    else if ((input.inputs['W_USAGE'] ?? 0) > 0 && plan.items.some((i) => i.utility === 'water')) checks.push({ utility: 'water', key: 'W_USAGE' });

    const byUnit = (inp: EngineInput, u: Utility) => {
      const m = new Map<number, number>();
      for (const x of inp.meters) m.set(x.unitId, (m.get(x.unitId) ?? 0) + x[u]);
      return m;
    };
    let last: EngineInput | null = null;
    for (const c of checks) {
      const total = input.inputs[c.key] ?? 0;
      if (!(total > 0)) continue;
      const cur = byUnit(input, c.utility);
      const sum = [...cur.values()].reduce((s, v) => s + v, 0);
      if (sum <= total * USAGE_SUM_TOLERANCE) continue;
      last ??= await this.engineInput(buildingId, prevMonth(month));
      const prev = byUnit(last, c.utility);
      const name = (uid: number) => {
        const u = input.units.find((x) => x.unitId === uid)!;
        return `${u.unitNumber}호 ${u.name}`.trim();
      };
      const ratio = (uid: number) => (cur.get(uid) ?? 0) / (prev.get(uid) ?? 0);
      const jumped = [...cur.keys()].filter((uid) => (prev.get(uid) ?? 0) > 0 && ratio(uid) > 2).sort((a, b) => ratio(b) - ratio(a));
      const suspects = jumped.length ? jumped : [...cur.keys()].sort((a, b) => (cur.get(b) ?? 0) - (cur.get(a) ?? 0)).slice(0, 3);
      const list = suspects
        .slice(0, 5)
        .map((uid) => `${name(uid)} ${fmtUsage(cur.get(uid) ?? 0, c.utility)}${jumped.length ? `(지난달 ${fmtUsage(prev.get(uid) ?? 0, c.utility)})` : ''}`)
        .join(', ');
      issues.push({
        level: 'error',
        message:
          `호실 ${c.utility === 'water' ? '수도' : '전기'} 사용량 합계(${fmtUsage(sum, c.utility)})가 고지서 사용량(${fmtUsage(total, c.utility)})보다 훨씬 큽니다. ` +
          `${jumped.length ? '지난달보다 크게 늘어난 호실' : '사용량이 큰 호실'}: ${list}. 검침값(소수점 빠짐·빈칸 등)을 확인해주세요`,
      });
    }
    return issues;
  }

  // ── 확정·명세서 ──────────────────────────────────────────

  /** 확정: 미리보기와 같은 계산을 명세서 스냅샷으로 저장. 다시 확정하면 계산 칸만 바뀌고 입금 기록은 남는다. */
  async issue(buildingId: number, month: string, userId: number) {
    const p = await this.preview(buildingId, month);
    const errors = p.issues.filter((i) => i.level === 'error');
    if (errors.length || !p.result) throw new BadRequestException(errors.map((e) => e.message).join(' / ') || '계산할 수 없습니다');
    const eff = await this.plans.effective(buildingId, month);
    const input = await this.engineInput(buildingId, month);
    const result = p.result;
    await this.dataSource.transaction(async (em) => {
      for (const u of result.units) {
        await em.query(
          `INSERT INTO statements (building_id, unit_id, charge_month, unit_number, unit_name, area, usage, lines, group_totals, total,
                                   plan_snapshot, inputs_snapshot, status, issued_at, issued_by)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'issued',now(),$13)
           ON CONFLICT (building_id, charge_month, unit_number) DO UPDATE SET
             unit_id = EXCLUDED.unit_id, unit_name = EXCLUDED.unit_name, area = EXCLUDED.area, usage = EXCLUDED.usage,
             lines = EXCLUDED.lines, group_totals = EXCLUDED.group_totals, total = EXCLUDED.total,
             plan_snapshot = EXCLUDED.plan_snapshot, inputs_snapshot = EXCLUDED.inputs_snapshot,
             status = 'issued', issued_at = now(), issued_by = EXCLUDED.issued_by, updated_at = now()`,
          [
            buildingId,
            u.unitId,
            month,
            u.unitNumber,
            u.name,
            u.area,
            JSON.stringify(u.usage),
            JSON.stringify(u.lines),
            JSON.stringify(u.groups),
            u.total.amount,
            JSON.stringify(eff.definition),
            JSON.stringify(input.inputs),
            userId,
          ],
        );
      }
      // 이번 계산에 없는 호실의 예전 확정분은(입금 기록이 없으면) 지운다
      await em.query(
        `DELETE FROM statements WHERE building_id = $1 AND charge_month = $2 AND NOT (unit_number = ANY($3::int[])) AND paid_amount = 0`,
        [buildingId, month, result.units.map((u) => u.unitNumber)],
      );
    });
    return this.statements(buildingId, month);
  }

  async statements(buildingId: number, month: string) {
    assertMonth(month);
    // paid_at(DATE)은 글자로 읽는다 — pg 가 Date 로 바꾸면 서버 시간대에 따라 하루 앞당겨진다
    const rows = await this.dataSource.query(
      `SELECT *, to_char(paid_at, 'YYYY-MM-DD') AS paid_on FROM statements WHERE building_id = $1 AND charge_month = $2 ORDER BY unit_number`,
      [buildingId, month],
    );
    return rows.map((r: any) => ({
      statementId: Number(r.statement_id),
      unitId: r.unit_id === null ? null : Number(r.unit_id),
      chargeMonth: r.charge_month,
      unitNumber: Number(r.unit_number),
      unitName: r.unit_name,
      area: num(r.area),
      usage: r.usage,
      lines: r.lines,
      groups: r.group_totals,
      total: num(r.total),
      status: r.status,
      issuedAt: r.issued_at,
      paidAmount: num(r.paid_amount),
      paidAt: r.paid_on,
      memo: r.memo,
      plan: r.plan_snapshot ? { preset: r.plan_snapshot.preset ?? null, groups: r.plan_snapshot.groups } : null,
    }));
  }

  /** 입금 기록(완납·부분·메모). 금액은 0 이상. */
  async recordPayment(buildingId: number, statementId: number, dto: { paidAmount?: number; paidAt?: string | null; memo?: string | null }) {
    const rows = await this.dataSource.query('SELECT charge_month FROM statements WHERE statement_id = $1 AND building_id = $2', [statementId, buildingId]);
    if (!rows.length) throw new NotFoundException('명세서를 찾을 수 없습니다');
    const paid = dto.paidAmount === undefined ? undefined : Number(dto.paidAmount);
    if (paid !== undefined && (!Number.isFinite(paid) || paid < 0)) throw new BadRequestException('입금액은 0 이상의 숫자여야 합니다');
    if (dto.paidAt && !/^\d{4}-\d{2}-\d{2}$/.test(dto.paidAt)) throw new BadRequestException('입금일은 YYYY-MM-DD 형식이어야 합니다');
    await this.dataSource.query(
      `UPDATE statements SET
         paid_amount = COALESCE($3, paid_amount),
         paid_at = CASE WHEN $4::text = '__keep__' THEN paid_at ELSE $4::date END,
         memo = CASE WHEN $5::text = '__keep__' THEN memo ELSE $5 END,
         updated_at = now()
       WHERE statement_id = $1 AND building_id = $2`,
      [statementId, buildingId, paid ?? null, dto.paidAt === undefined ? '__keep__' : dto.paidAt, dto.memo === undefined ? '__keep__' : dto.memo],
    );
    return (await this.statements(buildingId, rows[0].charge_month)).find((s: { statementId: number }) => s.statementId === statementId);
  }

  // ── 월 현황(첫 화면) ─────────────────────────────────────

  /** 최근 count 달의 진행 현황 — 검침·고지서·확정·입금. until 이 없으면 이번 달(한국 시간)까지. */
  async overview(buildingId: number, count = 6, until?: string) {
    const end = until && MONTH_RE.test(until) ? until : kstMonth();
    const months: string[] = [end];
    while (months.length < Math.min(Math.max(count, 1), 24)) months.push(prevMonth(months[months.length - 1]));
    const meters = Number((await this.dataSource.query('SELECT COUNT(*)::int AS n FROM rooms WHERE building_id = $1', [buildingId]))[0].n);
    const bills = await this.dataSource.query(
      'SELECT charge_month, COUNT(DISTINCT room_id)::int AS n FROM bills WHERE building_id = $1 AND charge_month = ANY($2) GROUP BY 1',
      [buildingId, months],
    );
    const inputs = await this.dataSource.query('SELECT charge_month FROM calc_inputs WHERE building_id = $1 AND charge_month = ANY($2)', [buildingId, months]);
    const st = await this.dataSource.query(
      `SELECT charge_month, COUNT(*)::int AS n, SUM(total) AS total, SUM(LEAST(paid_amount, total)) AS paid,
              COUNT(*) FILTER (WHERE paid_amount >= total AND total > 0)::int AS paid_n, MAX(issued_at) AS at
       FROM statements WHERE building_id = $1 AND charge_month = ANY($2) GROUP BY 1`,
      [buildingId, months],
    );
    const legacy = await this.dataSource.query(
      'SELECT charge_month, COUNT(*)::int AS n, SUM(total_cost) AS total FROM bill_histories WHERE building_id = $1 AND charge_month = ANY($2) GROUP BY 1',
      [buildingId, months],
    );
    const by = (rows: any[]) => new Map<string, any>(rows.map((r) => [r.charge_month, r]));
    const b = by(bills), i = by(inputs), s = by(st), l = by(legacy);
    return {
      meters,
      months: months.map((m) => ({
        month: m,
        readings: { entered: b.get(m)?.n ?? 0, total: meters },
        inputsSaved: i.has(m),
        statements: s.has(m)
          ? { count: s.get(m).n, total: num(s.get(m).total), paidCount: s.get(m).paid_n, paidAmount: num(s.get(m).paid), issuedAt: s.get(m).at }
          : null,
        legacyHistory: l.has(m) ? { count: l.get(m).n, total: num(l.get(m).total) } : null,
      })),
    };
  }
}

/** 이번 달(한국 시간) YYYYMM. */
export function kstMonth(now = new Date()): string {
  const k = new Date(now.getTime() + 9 * 3600 * 1000);
  return `${k.getUTCFullYear()}${String(k.getUTCMonth() + 1).padStart(2, '0')}`;
}
