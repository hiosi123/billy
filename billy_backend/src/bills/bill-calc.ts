/**
 * 관리비 계산 코어 — 기존 Go 백엔드(app/apis/handlers.go, bill_dto.go)의
 * Bill 구조체 메서드 + 헬퍼를 공식 그대로 옮긴 것. 숫자 결과가 동일해야 한다.
 */

/** 계산 누적용 한 호실(roomNumber 단위)의 청구 결과. */
export class BillCalc {
  electricityCost = 0;
  electricityCostCommon = 0;
  electricityCostTax = 0;
  electricityCostFund = 0;
  electricityCostTotal = 0;

  waterCostSupply = 0;
  waterCostSewer = 0;
  waterCostCommon = 0;
  waterCostTotal = 0;

  totalCost = 0;

  // 집계용(응답 직렬화 제외 대상이지만 JS에선 그대로 둔다)
  waterUsage = 0;
  electricityUsage = 0;

  buildingId = 0;
  roomNumber = 0;

  /** 전체 소계: 전기 합 + TV료, 수도 합, 총합. (Go: CalculateTotal) */
  calculateTotal(tvCost: number): void {
    this.electricityCostTotal =
      this.electricityCost + this.electricityCostCommon + this.electricityCostTax + this.electricityCostFund + tvCost;
    this.waterCostTotal = this.waterCostSupply + this.waterCostSewer + this.waterCostCommon;
    this.totalCost = this.electricityCostTotal + this.waterCostTotal;
  }

  /** 해당 방의 전기세 = 사용량 × kWh단가. (Go: CalculateElectricityCost) */
  calculateElectricityCost(electricityUsage: number, costPerKWh: number): void {
    this.electricityCost = electricityUsage * costPerKWh;
  }

  /** 전체 공동 전기요금 = 전체 전기요금 − 전체 측정 전기요금합. (Go: CalculateTotalCommonCost) */
  calculateTotalCommonCost(electricityBill: number, totalElectricityCommonCost: number): number {
    return electricityBill - totalElectricityCommonCost;
  }

  /** 해당 방의 공동 전기요금 = 공동요금 × 방면적 / 전체면적. (Go: CalculateElectricityCommonCost) */
  calculateElectricityCommonCost(totalCommonCost: number, roomSize: number, totalSize: number): void {
    this.electricityCostCommon = (totalCommonCost * roomSize) / totalSize;
  }

  /** 부가가치세 10%. (Go: CalculateElectricityTax) */
  calculateElectricityTax(): void {
    this.electricityCostTax = (this.electricityCost + this.electricityCostCommon) * 0.1;
  }

  /** 전력산업기반기금 2.7%. (Go: CalculateElectricityFund) */
  calculateElectricityFund(): void {
    this.electricityCostFund = (this.electricityCost + this.electricityCostCommon) * 0.027;
  }

  /** 상수도 요금 = 요금 × 방사용량 / 전체사용량. (Go: CalculateWaterCostSupply) */
  calculateWaterCostSupply(waterBill: number, totalWaterUsage: number, roomWaterUsage: number): void {
    this.waterCostSupply = (waterBill * roomWaterUsage) / totalWaterUsage;
  }

  /** 하수도 요금 = 요금 × 방사용량 / 전체사용량. (Go: CalculateWaterCostSewer) */
  calculateWaterCostSewer(waterBill: number, totalWaterUsage: number, roomWaterUsage: number): void {
    this.waterCostSewer = (waterBill * roomWaterUsage) / totalWaterUsage;
  }

  /** 전체 공동 수도요금 = 전체 − (상수도 + 하수도). (Go: CalculateWaterCostCommon) */
  calculateWaterCostCommon(waterBill: number, waterSupplyBill: number, waterSewerBill: number): number {
    return waterBill - (waterSupplyBill + waterSewerBill);
  }

  /** 해당 방 공동 수도요금 = 공동요금 × 방사용량 / 전체사용량. (Go: CalculateWaterCommonCost) */
  calculateWaterCommonCost(totalCommonCost: number, totalWaterUsage: number, roomWaterUsage: number): void {
    this.waterCostCommon = (totalCommonCost * roomWaterUsage) / totalWaterUsage;
  }

  /** 모든 금액 필드 반올림. (Go: math.Round 일괄 적용) */
  roundMoney(): void {
    this.electricityCost = Math.round(this.electricityCost);
    this.electricityCostCommon = Math.round(this.electricityCostCommon);
    this.electricityCostTax = Math.round(this.electricityCostTax);
    this.electricityCostFund = Math.round(this.electricityCostFund);
    this.electricityCostTotal = Math.round(this.electricityCostTotal);
    this.waterCostSupply = Math.round(this.waterCostSupply);
    this.waterCostSewer = Math.round(this.waterCostSewer);
    this.waterCostCommon = Math.round(this.waterCostCommon);
    this.waterCostTotal = Math.round(this.waterCostTotal);
    this.totalCost = Math.round(this.totalCost);
  }
}

/** 정수부 자릿수 기준 다음 10의 거듭제곱. (Go: getNextPowerOf10) */
export function getNextPowerOf10(n: number): number {
  if (n <= 0) return 1;
  const intPart = Math.floor(n);
  const digits = Math.floor(Math.log10(intPart)) + 1;
  return Math.pow(10, digits);
}

/**
 * 계량기 사용량 차이. 음수면(계량기 한 바퀴 돌아간 경우) 10의 거듭제곱을
 * 롤오버 지점으로 보정한다. multi 는 계량기 배수. (Go: calculateDifference)
 */
export function calculateDifference(a: number, b: number, multi: number): number {
  a = a * multi;
  b = b * multi;

  const diff = b - a;
  if (diff < 0) {
    const larger = b > a ? b : a;
    const rolloverPoint = getNextPowerOf10(larger);
    return rolloverPoint - a + b;
  }
  return diff;
}

/** 1원 단위 절삭(10원 단위) + 천 단위 콤마. (Go: formatKoreanMoney) */
export function formatKoreanMoney(amount: number): string {
  const truncated = Math.floor(amount / 10) * 10;
  return Math.trunc(truncated).toLocaleString('en-US');
}
