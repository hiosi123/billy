/**
 * 관리비 계산 엔진 — 타입.
 *
 * 건물마다 '요금표'(ChargePlanDef)에 항목(ChargeItem)을 나열하고, 엔진이 그 순서대로 호실별 금액을 계산한다.
 * 기존 계산은 프리셋 legacy-v1 로 표현되며, 정답지(legacyCalculate)와 원 단위까지 같아야 한다.
 */

/** 항목 방식. 화면에는 쉬운 말로 보여 준다(METHOD_LABELS). */
export type ChargeMethod =
  | 'UNIT_PRICE' // 호실 사용량 × (고지서 금액 ÷ 고지서 사용량)
  | 'REMAINDER' // 고지서 금액 − 호실 사용분 합계 → 면적/사용량/균등으로
  | 'USAGE_SPLIT' // 금액 × 호실 사용량 ÷ 사용량 합계
  | 'AREA_SPLIT' // 금액 × 면적 ÷ 총면적
  | 'EQUAL_SPLIT' // 금액 ÷ 호실 수
  | 'FIXED_PER_UNIT' // 호실마다 고정액(호실별로 다르게도)
  | 'PERCENT_OF' // 다른 항목 합 × 요율
  | 'UNIT_ATTR' // 호실 고정값(화재보험료 등)
  | 'DIRECT'; // 그달 호실별 직접 입력

export const METHOD_LABELS: Record<ChargeMethod, string> = {
  UNIT_PRICE: '사용량 × 단가(고지서 금액 ÷ 사용량)',
  REMAINDER: '고지서에서 사용분을 뺀 나머지를 나눔',
  USAGE_SPLIT: '사용량 비율로 나눔',
  AREA_SPLIT: '면적 비율로 나눔',
  EQUAL_SPLIT: '호실 수로 똑같이 나눔',
  FIXED_PER_UNIT: '호실마다 고정 금액',
  PERCENT_OF: '다른 항목의 % (부가세 등)',
  UNIT_ATTR: '호실에 정해 둔 금액(화재보험료 등)',
  DIRECT: '그달 호실별로 직접 입력',
};

export type Utility = 'electricity' | 'water';

/** 면적 배분 계산 순서 — 결과 끝자리가 달라질 수 있어 기존 방식을 그대로 고를 수 있게 둔다. */
export type AreaFormula =
  | 'mul_div' // (금액 × 면적) ÷ 총면적 — 기존 공용전기
  | 'ratio'; // 금액 × (면적 ÷ 총면적) — 기존 엑셀 관리비

/**
 * 금액 출처: 월 입력값(input) 또는 고정 금액(amount). minusInputs 가 있으면
 * 금액 − (빼는 값들의 합) — 기존 공용수도 = 수도요금 − (상수도 + 하수도).
 */
export interface AmountSource {
  input?: string;
  amount?: number;
  minusInputs?: string[];
}

export interface ChargeItem {
  /** 항목 고유 코드(영문·숫자·_). 참조·명세서 줄 식별에 쓴다. */
  code: string;
  /** 명세서에 보일 이름. */
  label: string;
  /** 묶음(소계 단위) 코드 — plan.groups 에 이름이 있다. */
  group: string;
  method: ChargeMethod;

  utility?: Utility; // UNIT_PRICE · USAGE_SPLIT · (REMAINDER split=usage)
  cost?: AmountSource; // UNIT_PRICE 고지서 금액 · REMAINDER 전체 금액 · *_SPLIT 나눌 금액
  usageInput?: string; // UNIT_PRICE 고지서 총 사용량 입력 키
  of?: string; // REMAINDER: 빼는 사용분 항목(UNIT_PRICE) 코드
  split?: 'area' | 'usage' | 'equal'; // REMAINDER 나머지를 나누는 기준
  areaFormula?: AreaFormula; // 면적 배분 계산 순서(기본 mul_div)
  refs?: string[]; // PERCENT_OF 대상 항목 코드(이 순서로 더한 뒤 곱한다)
  rate?: number; // PERCENT_OF 요율(0.1 = 10%)
  amount?: number; // FIXED_PER_UNIT 기본 금액
  perUnit?: Record<string, number>; // FIXED_PER_UNIT 호실별 금액(호수 → 금액)
  attr?: 'baseCost'; // UNIT_ATTR 호실 값
  directKey?: string; // DIRECT 월 입력 키 — 값은 inputs[`${directKey}:${호수}`]

  /** 대상 호실(호수). 없으면 전체. */
  scope?: { only?: number[]; exclude?: number[] };
  /** 법정 관리비 14항목 분류(상가임대차법 제19조의2) — 명세서 내역 제공용. */
  category?: string;
  /** 명세서 줄에서 숨김(합계에는 들어간다). */
  hidden?: boolean;
}

export interface ChargeGroup {
  code: string;
  label: string;
}

export interface ChargePlanDef {
  /** 시작한 프리셋(legacy-v1 등). 사용자가 고친 뒤에도 출처로 남긴다. */
  preset?: string;
  /**
   * 반올림: end = 반올림 전 값으로 소계를 내고 마지막에 반올림(기존 방식),
   * item = 항목마다 반올림한 값을 더함(명세서 줄의 합 = 소계).
   */
  roundingMode: 'end' | 'item';
  /** 청구 대상: with_meters = 이번 달 검침이 있는 호실만(기존), all = 모든 호실. */
  billedUnits: 'with_meters' | 'all';
  groups: ChargeGroup[];
  items: ChargeItem[];
}

export interface EngineUnit {
  unitId: number;
  unitNumber: number;
  name: string;
  area: number;
  baseCost: number;
}

/** 계량기 한 행의 그달 사용량(배수 반영). 순서 = bill 순서 — 합계의 끝자리가 순서에 좌우된다. */
export interface EngineMeter {
  unitId: number;
  electricity: number;
  water: number;
}

export interface EngineInput {
  /** 건물의 모든 호실(면적 분모에 들어간다). */
  units: EngineUnit[];
  meters: EngineMeter[];
  /** 월 입력값(고지서 금액 등). */
  inputs: Record<string, number>;
}

export interface EngineLine {
  code: string;
  label: string;
  group: string;
  raw: number;
  amount: number;
  hidden?: boolean;
  category?: string;
}

export interface EngineGroupTotal {
  group: string;
  label: string;
  raw: number;
  amount: number;
}

export interface EngineUnitResult {
  unitId: number;
  unitNumber: number;
  name: string;
  area: number;
  usage: Record<Utility, number>;
  lines: EngineLine[];
  groups: EngineGroupTotal[];
  total: { raw: number; amount: number };
}

export interface EngineResult {
  units: EngineUnitResult[];
  /** 항목별 건물 합계(반올림 금액 합)와 나눈 원금 — '호실 합계 = 고지서' 검산용. */
  itemTotals: { code: string; label: string; allocated: number; pool: number | null }[];
  warnings: string[];
}
