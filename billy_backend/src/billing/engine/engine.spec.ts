import { computePlan, PlanError, validatePlan } from './engine';
import { EngineInput } from './types';
import { legacyCalculate, LegacyBill, LegacyCalcInput, LegacyRoom } from '../legacy-calc';
import { basicV1Plan, legacyV1Plan, LegacyFeeAmounts, requiredInputs } from '../presets';
import { BUILDING_ROOMS, MONTHS } from '../testing/golden-2026';

/** 기존 데이터(rooms 행·bills)를 엔진 입력으로 — 호실 = 같은 호수의 첫 행(면적·기본료), 계량기 = bill 순서. */
function toEngineInput(rooms: LegacyRoom[], bills: LegacyBill[], c: LegacyCalcInput, baseCost: Record<number, number> = {}): EngineInput {
  const unitIdByRoomNo = new Map<number, number>();
  const units: EngineInput['units'] = [];
  for (const r of rooms) {
    if (unitIdByRoomNo.has(r.roomNumber)) continue;
    unitIdByRoomNo.set(r.roomNumber, r.roomNumber);
    units.push({ unitId: r.roomNumber, unitNumber: r.roomNumber, name: `${r.roomNumber}`, area: r.roomSpace, baseCost: baseCost[r.roomNumber] ?? 0 });
  }
  const roomNoById = new Map(rooms.map((r) => [r.roomId, r.roomNumber]));
  const meters = bills
    .filter((b) => roomNoById.has(b.roomId))
    .map((b) => ({ unitId: roomNoById.get(b.roomId)!, electricity: b.electricityUsage, water: b.waterUsage }));
  return {
    units,
    meters,
    inputs: {
      E_COST: c.electricityTotalCost,
      E_USAGE: c.electricityTotalUsage,
      W_TOTAL: c.waterTotalCost,
      W_SUPPLY: c.waterSupplyCost,
      W_SEWER: c.waterSewerCost,
    },
  };
}

/** 엔진(legacy-v1) 결과와 정답지(legacyCalculate)의 모든 금액이 같은지 비교. 다르면 차이를 문자열로. */
function diffAgainstOracle(rooms: LegacyRoom[], bills: LegacyBill[], c: LegacyCalcInput): string[] {
  const oracle = legacyCalculate(rooms, bills, c).byRoomNumber;
  const engine = computePlan(legacyV1Plan(), toEngineInput(rooms, bills, c));
  const out: string[] = [];
  const engineNos = engine.units.map((u) => u.unitNumber);
  const oracleNos = [...oracle.keys()];
  if (JSON.stringify(engineNos) !== JSON.stringify(oracleNos)) out.push(`호실 순서 ${engineNos} vs ${oracleNos}`);
  for (const u of engine.units) {
    const o = oracle.get(u.unitNumber)!;
    const line = (code: string) => u.lines.find((l) => l.code === code)?.amount;
    const group = (g: string) => u.groups.find((x) => x.group === g)!;
    const pairs: [string, number | undefined, number][] = [
      ['elec_usage', line('elec_usage'), o.electricityCost],
      ['elec_common', line('elec_common'), o.electricityCostCommon],
      ['elec_vat', line('elec_vat'), o.electricityCostTax],
      ['elec_fund', line('elec_fund'), o.electricityCostFund],
      ['electricity', group('electricity').amount, o.electricityCostTotal],
      ['water_supply', line('water_supply'), o.waterCostSupply],
      ['water_sewer', line('water_sewer'), o.waterCostSewer],
      ['water_common', line('water_common'), o.waterCostCommon],
      ['water', group('water').amount, o.waterCostTotal],
      ['total(전기+수도)', Math.round(group('electricity').raw + group('water').raw), o.totalCost],
    ];
    for (const [name, got, want] of pairs) {
      if (!Object.is(got, want)) out.push(`${u.unitNumber}호 ${name}: 엔진 ${got} vs 정답지 ${want}`);
    }
  }
  return out;
}

describe('엔진 legacy-v1 = 기존 계산(정답지)', () => {
  for (const month of Object.keys(MONTHS)) {
    it(`운영 ${month}: 전기·수도 모든 항목·소계·합계가 같다`, () => {
      const { bills, input } = MONTHS[month];
      expect(diffAgainstOracle(BUILDING_ROOMS, bills, input)).toEqual([]);
    });
  }

  it('무작위 건물 2,000개(계량기 여러 개·면적 0·사용량 0 포함)에서도 모두 같다', () => {
    let seed = 20261106;
    const rnd = () => {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    };
    const pick = <T>(xs: T[]) => xs[Math.floor(rnd() * xs.length)];
    const failures: string[] = [];
    for (let t = 0; t < 2000; t++) {
      const rooms: LegacyRoom[] = [];
      const bills: LegacyBill[] = [];
      const unitCount = 1 + Math.floor(rnd() * 12);
      let roomId = 1;
      for (let u = 0; u < unitCount; u++) {
        const roomNumber = 100 * (1 + Math.floor(u / 3)) + (u % 3) + 1;
        const meters = 1 + Math.floor(rnd() * 3);
        for (let m = 0; m < meters; m++) {
          const space = m === 0 ? pick([0, Math.round(rnd() * 50000) / 100, Math.round(rnd() * 400) / 10]) : pick([0, 0, Math.round(rnd() * 3000) / 10]);
          rooms.push({ roomId, roomNumber, roomSpace: space });
          if (rnd() < 0.9) {
            bills.push({
              billId: roomId,
              roomId,
              electricityUsage: pick([0, Math.round(rnd() * 1000000) / 100, Math.round(rnd() * 50000) / 4]),
              waterUsage: pick([0, Math.floor(rnd() * 300), Math.round(rnd() * 5000) / 100]),
            });
          }
          roomId++;
        }
      }
      if (bills.length === 0) continue;
      // bill 순서를 섞는다(합계 끝자리가 순서에 좌우되는지까지 확인)
      for (let i = bills.length - 1; i > 0; i--) {
        const j = Math.floor(rnd() * (i + 1));
        [bills[i], bills[j]] = [bills[j], bills[i]];
      }
      const totalE = bills.reduce((s, b) => s + b.electricityUsage, 0);
      const c: LegacyCalcInput = {
        buildingId: 1,
        electricityTotalCost: Math.round(rnd() * 9000000),
        electricityTotalUsage: Math.max(1, Math.round(totalE * (0.8 + rnd() * 0.6))),
        waterTotalCost: Math.round(rnd() * 2000000),
        waterSupplyCost: Math.round(rnd() * 800000),
        waterSewerCost: Math.round(rnd() * 900000),
      };
      // 수도 사용량 합이나 총면적이 0 이면 기존 계산은 NaN 을 낸다(알려진 버그) — 엔진은 배분하지 않고 경고. 비교에서 뺀다.
      if (bills.reduce((s, b) => s + b.waterUsage, 0) === 0) continue;
      const firstRowArea = new Map<number, number>();
      for (const r of rooms) if (!firstRowArea.has(r.roomNumber)) firstRowArea.set(r.roomNumber, r.roomSpace);
      if ([...firstRowArea.values()].reduce((s, a) => s + a, 0) === 0) continue;
      const d = diffAgainstOracle(rooms, bills, c);
      if (d.length) failures.push(`#${t}: ${d.slice(0, 3).join(' | ')}`);
    }
    expect(failures.slice(0, 5)).toEqual([]);
  });

  it('관리비 묶음 = 기존 엑셀 식(금액 × (면적 ÷ 총면적), 7항목 + 화재보험료)', () => {
    const fees: LegacyFeeAmounts = {
      generalManagementFee: 1834920,
      publicInspectionFee: 1160817,
      fireManagementFee: 224000,
      elevatorMaintenanceFee: 220000,
      septicTankManagementFee: 236020,
      electricalManagementFee: 259720,
      parkingManagementFee: 382418,
    };
    const baseCost = { 101: 332850, 102: 237890, 103: 150000, 201: 105920, 301: 193800, 401: 9740, 501: 169090 };
    const { bills, input } = MONTHS['202609'];
    const engine = computePlan(legacyV1Plan(fees), toEngineInput(BUILDING_ROOMS, bills, input, baseCost));
    const totalSpace = [118.8, 49.9, 197.6, 251.9, 391.7, 391.7, 391.7].reduce((s, a) => s + a, 0);
    for (const u of engine.units) {
      // excel.service.ts 와 같은 식·순서
      const ratio = u.area / totalSpace;
      const seven = [
        fees.generalManagementFee * ratio,
        fees.publicInspectionFee * ratio,
        fees.fireManagementFee * ratio,
        fees.elevatorMaintenanceFee * ratio,
        fees.septicTankManagementFee * ratio,
        fees.electricalManagementFee * ratio,
        fees.parkingManagementFee * ratio,
      ];
      const totalFeeWI = seven[0] + seven[1] + seven[2] + seven[3] + seven[4] + seven[5] + seven[6];
      const totalFee = totalFeeWI + baseCost[u.unitNumber as keyof typeof baseCost];
      const feeLines = u.lines.filter((l) => l.group === 'fee');
      expect(feeLines.slice(0, 7).map((l) => l.raw)).toEqual(seven);
      expect(u.groups.find((g) => g.group === 'fee')!.raw).toBe(totalFee);
    }
  });
});

describe('엔진 — 방식별 동작', () => {
  const units = [
    { unitId: 1, unitNumber: 101, name: 'A', area: 100, baseCost: 0 },
    { unitId: 2, unitNumber: 102, name: 'B', area: 300, baseCost: 0 },
  ];
  const meters = [
    { unitId: 1, electricity: 100, water: 10 },
    { unitId: 2, electricity: 300, water: 30 },
  ];

  it('기본 상가형: 전기 청구금액을 사용분 + 공용(면적)으로 나눠 호실 합계 = 고지서', () => {
    const plan = basicV1Plan();
    plan.items = plan.items.map((i) => (i.group === 'fee' ? { ...i, amount: 40000 } : i));
    const r = computePlan(plan, { units, meters, inputs: { E_COST: 100000, E_USAGE: 500, W_TOTAL: 8000 } });
    const sum = (code: string) => r.units.reduce((s, u) => s + (u.lines.find((l) => l.code === code)?.amount ?? 0), 0);
    expect(sum('elec_usage') + sum('elec_common')).toBe(100000);
    expect(sum('water')).toBe(8000);
    expect(sum('general')).toBe(40000);
    expect(r.warnings).toEqual([]);
  });

  it('균등·고정·호실별 고정·직접 입력·범위(제외 호실)', () => {
    const r = computePlan(
      {
        roundingMode: 'item',
        billedUnits: 'all',
        groups: [{ code: 'fee', label: '관리비' }],
        items: [
          { code: 'clean', label: '청소비', group: 'fee', method: 'EQUAL_SPLIT', amount: 10001 },
          { code: 'tv', label: 'TV', group: 'fee', method: 'FIXED_PER_UNIT', amount: 2500, perUnit: { '102': 0 } },
          { code: 'elev', label: '승강기', group: 'fee', method: 'AREA_SPLIT', amount: 9000, scope: { exclude: [101] } },
          { code: 'repair', label: '수선비', group: 'fee', method: 'DIRECT' },
        ],
      },
      { units, meters, inputs: { 'repair:101': 33000 } },
    );
    const a = r.units[0].lines.map((l) => [l.code, l.amount]);
    const b = r.units[1].lines.map((l) => [l.code, l.amount]);
    expect(a).toEqual([['clean', 5001], ['tv', 2500], ['repair', 33000]]); // 5000.5 → 5001(반올림)
    expect(b).toEqual([['clean', 5001], ['tv', 0], ['elev', 9000], ['repair', 0]]);
    expect(r.units[0].total.amount).toBe(5001 + 2500 + 33000); // item 모드: 줄 금액의 합
  });

  it('면적이 있는데 청구되지 않은 호실이 있으면 배분 안 된 금액을 경고', () => {
    const plan = legacyV1Plan({ generalManagementFee: 100000 });
    const r = computePlan(plan, {
      units: [...units, { unitId: 3, unitNumber: 103, name: 'C', area: 600, baseCost: 0 }],
      meters,
      inputs: { E_COST: 1000, E_USAGE: 400, W_TOTAL: 0, W_SUPPLY: 0, W_SEWER: 0 },
    });
    expect(r.warnings.some((w) => w.includes('일반관리비') && w.includes('60,000원'))).toBe(true);
  });

  it('잘못된 요금표는 한국어로 막는다', () => {
    expect(() =>
      validatePlan({
        roundingMode: 'end',
        billedUnits: 'all',
        groups: [{ code: 'fee', label: '관리비' }],
        items: [{ code: 'vat', label: '부가세', group: 'fee', method: 'PERCENT_OF', refs: ['elec'], rate: 0.1 }],
      }),
    ).toThrow(PlanError);
    expect(() => computePlan(legacyV1Plan(), { units, meters, inputs: { E_COST: 1000 } })).toThrow('고지서 총 사용량');
  });

  it('요금표가 요구하는 월 입력 키', () => {
    expect(requiredInputs(legacyV1Plan())).toEqual(['E_COST', 'E_USAGE', 'W_SUPPLY', 'W_SEWER', 'W_TOTAL']);
  });
});
