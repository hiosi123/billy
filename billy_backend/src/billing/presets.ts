import { ChargeItem, ChargePlanDef } from './engine/types';

/**
 * 요금표 프리셋. 새 건물은 여기서 시작하고, 사용자가 항목을 고쳐 자기 건물 방식으로 만든다.
 *
 * legacy-v1 = 지금까지의 계산(Go 이식)을 그대로 옮긴 것 — engine.spec.ts 가 정답지(legacyCalculate)·기존 엑셀 식과
 * 원 단위까지 같은지 지킨다. 숫자를 바꾸지 말 것(요율이 바뀌면 사용자가 요금표에서 고친다).
 */

/** 월 입력값 키 — calc_inputs 의 기존 칸과 이어진다(고지서 사진 인식이 채우는 칸). */
export const INPUT_KEYS = {
  E_COST: 'E_COST', // 전체 전기요금(전기요금계)
  E_USAGE: 'E_USAGE', // 전체 전기 사용량(kWh)
  W_TOTAL: 'W_TOTAL', // 전체 수도요금
  W_USAGE: 'W_USAGE', // 전체 수도 사용량(㎥)
  W_SUPPLY: 'W_SUPPLY', // 상수도 요금
  W_SEWER: 'W_SEWER', // 하수도 요금
} as const;

/** 입력 키 → 화면 이름·단위. 요금표가 요구하는 입력만 고지서 화면에 나온다. */
export const INPUT_LABELS: Record<string, { label: string; unit: string }> = {
  E_COST: { label: '전체 전기요금', unit: '원' },
  E_USAGE: { label: '전체 전기 사용량', unit: 'kWh' },
  W_TOTAL: { label: '전체 수도요금', unit: '원' },
  W_USAGE: { label: '전체 수도 사용량', unit: 'm³' },
  W_SUPPLY: { label: '상수도 요금', unit: '원' },
  W_SEWER: { label: '하수도 요금', unit: '원' },
};

/** 법정 관리비 14항목(상가임대차법 제19조의2, 2026-05-12 시행) — 항목 분류용. */
export const LEGAL_CATEGORIES = [
  '일반관리비',
  '청소비',
  '경비비',
  '소독비',
  '승강기유지비',
  '냉난방비·급탕비',
  '수선유지비',
  '위탁관리수수료',
  '전기료',
  '수도료',
  '가스사용료',
  '정화조 오물처리 수수료',
  '폐기물 처리 수수료',
  '건물 전체 보험료',
] as const;

/** 기존 건물 고정 관리비 7칸(building_fees). */
export interface LegacyFeeAmounts {
  generalManagementFee: number;
  publicInspectionFee: number;
  fireManagementFee: number;
  elevatorMaintenanceFee: number;
  septicTankManagementFee: number;
  electricalManagementFee: number;
  parkingManagementFee: number;
}

const areaFee = (code: string, label: string, amount: number, category?: string): ChargeItem => ({
  code,
  label,
  group: 'fee',
  method: 'AREA_SPLIT',
  amount,
  areaFormula: 'ratio', // 기존 엑셀: 금액 × (면적 ÷ 총면적)
  ...(category ? { category } : {}),
});

/**
 * 기존 방식. 관리비 7항목 금액은 건물의 building_fees 값으로 채운다.
 * 이름은 기존 명세서(엑셀) 표기를 따른다. 법정 분류가 분명한 것만 category 를 넣었다
 * (공용점검비·소방·전기·주차관리비는 사장님이 요금표에서 정한다).
 */
export function legacyV1Plan(fees?: Partial<LegacyFeeAmounts>): ChargePlanDef {
  const f = (k: keyof LegacyFeeAmounts) => fees?.[k] ?? 0;
  return {
    preset: 'legacy-v1',
    roundingMode: 'end',
    billedUnits: 'with_meters',
    groups: [
      { code: 'fee', label: '관리비' },
      { code: 'electricity', label: '전기료' },
      { code: 'water', label: '수도료' },
    ],
    items: [
      areaFee('general', '일반관리비', f('generalManagementFee'), '일반관리비'),
      areaFee('inspection', '공용점검비', f('publicInspectionFee')),
      areaFee('fire_mgmt', '소방관리비', f('fireManagementFee')),
      areaFee('elevator', '승강기유지비', f('elevatorMaintenanceFee'), '승강기유지비'),
      areaFee('septic', '정화조관리비', f('septicTankManagementFee'), '정화조 오물처리 수수료'),
      areaFee('elec_mgmt', '전기관리비', f('electricalManagementFee')),
      areaFee('parking', '주차관리비', f('parkingManagementFee')),
      { code: 'fire_insurance', label: '화재보험료', group: 'fee', method: 'UNIT_ATTR', attr: 'baseCost', category: '건물 전체 보험료' },

      { code: 'elec_usage', label: '전기료', group: 'electricity', method: 'UNIT_PRICE', utility: 'electricity', cost: { input: 'E_COST' }, usageInput: 'E_USAGE', category: '전기료' },
      { code: 'elec_common', label: '공동전기료', group: 'electricity', method: 'REMAINDER', of: 'elec_usage', cost: { input: 'E_COST' }, split: 'area', areaFormula: 'mul_div', category: '전기료' },
      { code: 'elec_vat', label: '부가가치세', group: 'electricity', method: 'PERCENT_OF', refs: ['elec_usage', 'elec_common'], rate: 0.1, category: '전기료' },
      { code: 'elec_fund', label: '전력기금', group: 'electricity', method: 'PERCENT_OF', refs: ['elec_usage', 'elec_common'], rate: 0.027, category: '전기료' },
      { code: 'tv', label: 'TV 수신료', group: 'electricity', method: 'FIXED_PER_UNIT', amount: 2500, category: '전기료' },

      { code: 'water_supply', label: '상수도료', group: 'water', method: 'USAGE_SPLIT', utility: 'water', cost: { input: 'W_SUPPLY' }, category: '수도료' },
      { code: 'water_sewer', label: '하수도료', group: 'water', method: 'USAGE_SPLIT', utility: 'water', cost: { input: 'W_SEWER' }, category: '수도료' },
      { code: 'water_common', label: '공동요금', group: 'water', method: 'USAGE_SPLIT', utility: 'water', cost: { input: 'W_TOTAL', minusInputs: ['W_SUPPLY', 'W_SEWER'] }, category: '수도료' },
    ],
  };
}

/**
 * 기본 상가형 — 새 건물용 출발점. 전기는 고지서 청구금액(부가세·기금 포함)을 사용량 × 단가로 나누고
 * 남는 공용분을 면적으로 나눠 '호실 합계 = 고지서'가 되게 한다. 수도는 총액을 사용량 비율로.
 * 관리비 항목·금액은 건물에 맞게 고쳐 쓴다.
 */
export function basicV1Plan(): ChargePlanDef {
  return {
    preset: 'basic-v1',
    roundingMode: 'item',
    billedUnits: 'all',
    groups: [
      { code: 'fee', label: '관리비' },
      { code: 'electricity', label: '전기료' },
      { code: 'water', label: '수도료' },
    ],
    items: [
      { code: 'general', label: '일반관리비', group: 'fee', method: 'AREA_SPLIT', amount: 0, category: '일반관리비' },
      { code: 'cleaning', label: '청소비', group: 'fee', method: 'AREA_SPLIT', amount: 0, category: '청소비' },
      { code: 'elevator', label: '승강기유지비', group: 'fee', method: 'AREA_SPLIT', amount: 0, category: '승강기유지비' },
      { code: 'elec_usage', label: '전기 사용분', group: 'electricity', method: 'UNIT_PRICE', utility: 'electricity', cost: { input: 'E_COST' }, usageInput: 'E_USAGE', category: '전기료' },
      { code: 'elec_common', label: '공용 전기', group: 'electricity', method: 'REMAINDER', of: 'elec_usage', cost: { input: 'E_COST' }, split: 'area', category: '전기료' },
      { code: 'water', label: '수도료', group: 'water', method: 'USAGE_SPLIT', utility: 'water', cost: { input: 'W_TOTAL' }, category: '수도료' },
    ],
  };
}

export function blankPlan(): ChargePlanDef {
  return {
    preset: 'blank',
    roundingMode: 'item',
    billedUnits: 'all',
    groups: [{ code: 'fee', label: '관리비' }],
    items: [],
  };
}

export const PRESETS = [
  { id: 'legacy-v1', name: '기존 방식', description: '지금까지 쓰던 계산 그대로(관리비 7항목 면적 배분 + 전기·수도 징수대행).' },
  { id: 'basic-v1', name: '기본 상가형', description: '관리비 면적 배분 + 전기 청구금액을 사용량·면적으로 + 수도 사용량 비율.' },
  { id: 'blank', name: '빈 요금표', description: '항목을 처음부터 직접 만든다.' },
] as const;

export function presetPlan(id: string, fees?: Partial<LegacyFeeAmounts>): ChargePlanDef {
  if (id === 'legacy-v1') return legacyV1Plan(fees);
  if (id === 'basic-v1') return basicV1Plan();
  return blankPlan();
}

/** 요금표가 고지서 화면에서 요구하는 월 입력 키(순서 유지, 중복 없음). */
export function requiredInputs(plan: ChargePlanDef): string[] {
  const keys: string[] = [];
  const add = (k?: string) => {
    if (k && !keys.includes(k)) keys.push(k);
  };
  for (const item of plan.items) {
    add(item.cost?.input);
    item.cost?.minusInputs?.forEach(add);
    add(item.usageInput);
  }
  return keys;
}
