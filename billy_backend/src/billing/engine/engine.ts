import {
  AmountSource,
  ChargeItem,
  ChargePlanDef,
  EngineGroupTotal,
  EngineInput,
  EngineLine,
  EngineResult,
  EngineUnitResult,
  Utility,
} from './types';

/** 요금표 설정이 잘못됐거나 계산에 필요한 입력이 없을 때 — 화면에 그대로 보여 줄 한국어 메시지. */
export class PlanError extends Error {}

const CODE_RE = /^[A-Za-z0-9_]{1,40}$/;

/** 요금표가 계산 가능한지 확인한다(코드 중복·참조 순서·필수 설정). */
export function validatePlan(plan: ChargePlanDef): void {
  const groups = new Set(plan.groups.map((g) => g.code));
  const seen = new Map<string, ChargeItem>();
  for (const item of plan.items) {
    const name = `'${item.label || item.code}'`;
    if (!CODE_RE.test(item.code ?? '')) throw new PlanError(`${name}: 항목 코드는 영문·숫자·_ 만 쓸 수 있습니다`);
    if (seen.has(item.code)) throw new PlanError(`항목 코드 '${item.code}' 가 두 번 있습니다`);
    if (!item.label?.trim()) throw new PlanError(`'${item.code}': 항목 이름을 입력해주세요`);
    if (!groups.has(item.group)) throw new PlanError(`${name}: 묶음 '${item.group}' 이 없습니다`);
    switch (item.method) {
      case 'UNIT_PRICE':
        if (!item.utility || !item.cost || !item.usageInput) throw new PlanError(`${name}: 계량기 종류·고지서 금액·사용량 입력을 정해주세요`);
        break;
      case 'REMAINDER': {
        const of = item.of ? seen.get(item.of) : undefined;
        if (!of || of.method !== 'UNIT_PRICE') throw new PlanError(`${name}: 빼는 사용분 항목은 이 항목보다 앞의 '사용량 × 단가' 항목이어야 합니다`);
        if (!item.cost) throw new PlanError(`${name}: 나눌 전체 금액을 정해주세요`);
        break;
      }
      case 'USAGE_SPLIT':
        if (!item.utility || !item.cost) throw new PlanError(`${name}: 계량기 종류와 나눌 금액을 정해주세요`);
        break;
      case 'AREA_SPLIT':
      case 'EQUAL_SPLIT':
        if (!item.cost && item.amount === undefined) throw new PlanError(`${name}: 나눌 금액을 정해주세요`);
        break;
      case 'PERCENT_OF':
        if (!item.refs?.length) throw new PlanError(`${name}: 요율을 곱할 항목을 고르세요`);
        for (const r of item.refs) {
          if (!seen.has(r)) throw new PlanError(`${name}: '${r}' 는 이 항목보다 앞에 있어야 합니다`);
        }
        if (!Number.isFinite(item.rate)) throw new PlanError(`${name}: 요율을 입력해주세요`);
        break;
      case 'FIXED_PER_UNIT':
      case 'UNIT_ATTR':
      case 'DIRECT':
        break;
      default:
        throw new PlanError(`${name}: 알 수 없는 방식 '${(item as ChargeItem).method}'`);
    }
    seen.set(item.code, item);
  }
}

function inScope(item: ChargeItem, unitNumber: number): boolean {
  const s = item.scope;
  if (!s) return true;
  if (s.only?.length && !s.only.includes(unitNumber)) return false;
  if (s.exclude?.includes(unitNumber)) return false;
  return true;
}

/** 금액 출처 → 숫자. minusInputs: 금액 − (빼는 값들의 합) — 기존 공용수도 식과 같은 순서. */
function resolveAmount(src: AmountSource | undefined, inputs: Record<string, number>, fallback?: number): number {
  if (!src) return fallback ?? 0;
  const base = src.input !== undefined ? inputs[src.input] ?? 0 : src.amount ?? 0;
  if (!src.minusInputs?.length) return base;
  return base - src.minusInputs.reduce((s, k) => s + (inputs[k] ?? 0), 0);
}

/**
 * 요금표대로 호실별 금액을 계산한다. 반올림 전 값(raw)은 끝까지 그대로 들고 가고,
 * 합계의 덧셈 순서도 기존 계산과 같게 둔다(계량기 행 순서 → 호실 순서 → 항목 순서).
 */
export function computePlan(plan: ChargePlanDef, input: EngineInput): EngineResult {
  validatePlan(plan);
  const { inputs } = input;
  const warnings: string[] = [];

  const unitById = new Map(input.units.map((u) => [u.unitId, u]));
  const usage = new Map<number, Record<Utility, number>>();
  const metered: number[] = []; // 계량기가 있는 호실(처음 나온 순서) — 기존 결과 순서
  const meters = input.meters.filter((m) => unitById.has(m.unitId));
  for (const m of meters) {
    let u = usage.get(m.unitId);
    if (!u) {
      u = { electricity: 0, water: 0 };
      usage.set(m.unitId, u);
      metered.push(m.unitId);
    }
    u.electricity += m.electricity;
    u.water += m.water;
  }

  const billed = plan.billedUnits === 'all' ? input.units.map((u) => u.unitId) : metered;
  const usageOf = (unitId: number, utility: Utility) => usage.get(unitId)?.[utility] ?? 0;
  const unitNo = (unitId: number) => unitById.get(unitId)!.unitNumber;

  const itemByCode = new Map(plan.items.map((i) => [i.code, i]));
  const raw = new Map<string, Map<number, number>>(); // 항목 → 호실 → 반올림 전 값
  const rates = new Map<string, number>(); // UNIT_PRICE 단가
  const pools = new Map<string, number | null>();

  /** 면적 분모: 범위 안의 모든 호실(이번 달 청구 여부와 무관 — 기존 총면적과 같다). */
  const totalArea = (item: ChargeItem) =>
    input.units.reduce((s, u) => (inScope(item, u.unitNumber) ? s + u.area : s), 0);
  /** 사용량 분모: 범위 안 계량기 행의 사용량을 순서대로 더한다. */
  const totalUsage = (item: ChargeItem, utility: Utility) =>
    meters.reduce((s, m) => (inScope(item, unitNo(m.unitId)) ? s + m[utility] : s), 0);

  const splitArea = (item: ChargeItem, pool: number, vals: Map<number, number>) => {
    const total = totalArea(item);
    if (!(total > 0)) {
      if (pool !== 0) warnings.push(`'${item.label}': 면적 합계가 0이라 나눌 수 없습니다`);
      return;
    }
    for (const uid of billed) {
      const u = unitById.get(uid)!;
      if (!inScope(item, u.unitNumber)) continue;
      vals.set(uid, item.areaFormula === 'ratio' ? pool * (u.area / total) : (pool * u.area) / total);
    }
  };
  const splitUsage = (item: ChargeItem, utility: Utility, pool: number, vals: Map<number, number>) => {
    const total = totalUsage(item, utility);
    if (!(total > 0)) {
      if (pool !== 0) warnings.push(`'${item.label}': ${utility === 'water' ? '수도' : '전기'} 사용량 합계가 0이라 나눌 수 없습니다`);
      return;
    }
    for (const uid of billed) {
      if (!inScope(item, unitNo(uid))) continue;
      vals.set(uid, (pool * usageOf(uid, utility)) / total);
    }
  };
  const splitEqual = (item: ChargeItem, pool: number, vals: Map<number, number>) => {
    const targets = billed.filter((uid) => inScope(item, unitNo(uid)));
    if (targets.length === 0) return;
    for (const uid of targets) vals.set(uid, pool / targets.length);
  };

  for (const item of plan.items) {
    const vals = new Map<number, number>();
    switch (item.method) {
      case 'UNIT_PRICE': {
        const cost = resolveAmount(item.cost, inputs);
        const totalInput = inputs[item.usageInput!] ?? 0;
        if (!(totalInput > 0)) throw new PlanError(`'${item.label}': 고지서 총 사용량을 입력해주세요`);
        const rate = cost / totalInput;
        rates.set(item.code, rate);
        for (const uid of billed) {
          if (inScope(item, unitNo(uid))) vals.set(uid, usageOf(uid, item.utility!) * rate);
        }
        pools.set(item.code, null);
        break;
      }
      case 'REMAINDER': {
        const of = itemByCode.get(item.of!)!;
        const rate = rates.get(of.code)!;
        // 계량분 합계: 계량기 행마다 (사용량 × 단가)를 순서대로 더한다 — 기존 공용전기와 끝자리까지 같게.
        let usedCost = 0;
        for (const m of meters) {
          if (inScope(of, unitNo(m.unitId))) usedCost += m[of.utility!] * rate;
        }
        const pool = resolveAmount(item.cost, inputs) - usedCost;
        pools.set(item.code, pool);
        const split = item.split ?? 'area';
        if (split === 'area') splitArea(item, pool, vals);
        else if (split === 'usage') splitUsage(item, of.utility!, pool, vals);
        else splitEqual(item, pool, vals);
        break;
      }
      case 'USAGE_SPLIT': {
        const pool = resolveAmount(item.cost, inputs);
        pools.set(item.code, pool);
        splitUsage(item, item.utility!, pool, vals);
        break;
      }
      case 'AREA_SPLIT': {
        const pool = resolveAmount(item.cost, inputs, item.amount);
        pools.set(item.code, pool);
        splitArea(item, pool, vals);
        break;
      }
      case 'EQUAL_SPLIT': {
        const pool = resolveAmount(item.cost, inputs, item.amount);
        pools.set(item.code, pool);
        splitEqual(item, pool, vals);
        break;
      }
      case 'FIXED_PER_UNIT':
        for (const uid of billed) {
          const n = unitNo(uid);
          if (inScope(item, n)) vals.set(uid, item.perUnit?.[String(n)] ?? item.amount ?? 0);
        }
        pools.set(item.code, null);
        break;
      case 'PERCENT_OF':
        for (const uid of billed) {
          if (!inScope(item, unitNo(uid))) continue;
          const base = item.refs!.reduce((s, r) => s + (raw.get(r)!.get(uid) ?? 0), 0);
          vals.set(uid, base * item.rate!);
        }
        pools.set(item.code, null);
        break;
      case 'UNIT_ATTR':
        for (const uid of billed) {
          const u = unitById.get(uid)!;
          if (inScope(item, u.unitNumber)) vals.set(uid, u.baseCost);
        }
        pools.set(item.code, null);
        break;
      case 'DIRECT':
        for (const uid of billed) {
          const n = unitNo(uid);
          if (inScope(item, n)) vals.set(uid, inputs[`${item.directKey ?? item.code}:${n}`] ?? 0);
        }
        pools.set(item.code, null);
        break;
    }
    raw.set(item.code, vals);
  }

  const units: EngineUnitResult[] = billed.map((uid) => {
    const u = unitById.get(uid)!;
    const lines: EngineLine[] = [];
    for (const item of plan.items) {
      const v = raw.get(item.code)!.get(uid);
      if (v === undefined) continue;
      lines.push({
        code: item.code,
        label: item.label,
        group: item.group,
        raw: v,
        amount: Math.round(v),
        ...(item.hidden ? { hidden: true } : {}),
        ...(item.category ? { category: item.category } : {}),
      });
    }
    const groups: EngineGroupTotal[] = plan.groups.map((g) => {
      const members = lines.filter((l) => l.group === g.code);
      const groupRaw = members.reduce((s, l) => s + l.raw, 0);
      const amount = plan.roundingMode === 'item' ? members.reduce((s, l) => s + l.amount, 0) : Math.round(groupRaw);
      return { group: g.code, label: g.label, raw: groupRaw, amount };
    });
    const totalRaw = groups.reduce((s, g) => s + g.raw, 0);
    const totalAmount = plan.roundingMode === 'item' ? groups.reduce((s, g) => s + g.amount, 0) : Math.round(totalRaw);
    return {
      unitId: uid,
      unitNumber: u.unitNumber,
      name: u.name,
      area: u.area,
      usage: { electricity: usageOf(uid, 'electricity'), water: usageOf(uid, 'water') },
      lines,
      groups,
      total: { raw: totalRaw, amount: totalAmount },
    };
  });

  const itemTotals = plan.items.map((item) => {
    const allocated = units.reduce((s, u) => s + (u.lines.find((l) => l.code === item.code)?.amount ?? 0), 0);
    const pool = pools.get(item.code) ?? null;
    if (pool !== null && Number.isFinite(pool)) {
      const gap = Math.round(pool) - allocated;
      // 반올림 끝전(호실 수 이내)은 정상. 그보다 크면 면적이 있는데 청구되지 않은 호실 등이 있다.
      if (Math.abs(gap) > Math.max(units.length, 1)) {
        warnings.push(`'${item.label}': 나눌 금액 ${Math.round(pool).toLocaleString('ko-KR')}원 중 ${gap.toLocaleString('ko-KR')}원이 어느 호실에도 배분되지 않았습니다`);
      }
    }
    return { code: item.code, label: item.label, allocated, pool: pool === null ? null : Math.round(pool) };
  });

  return { units, itemTotals, warnings };
}
