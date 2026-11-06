import { BillCalc } from '../bills/bill-calc';

/**
 * 기존(Go 이식) 관리비 계산 — DB 를 모르는 순수 함수.
 *
 * bills.service.ts calculate() 의 계산부를 순서·반올림까지 그대로 옮겼다(2026-11).
 * 새 계산 엔진이 이 함수와 원 단위까지 같은 결과를 내는지 테스트의 '정답지'로 쓴다 —
 * 운영 2026-08·09 저장값과 7개 호수 모두 일치함을 legacy-calc.spec.ts 가 지킨다.
 *
 * 알아 둘 동작(고치지 말 것 — 고치면 정답지가 아니다):
 *  - 면적은 같은 호수(roomNumber)의 '첫 번째' 계량기 행 값을 쓴다(rooms 순서에 좌우된다).
 *  - 총면적에는 이번 달 bill 이 없는 호수도 들어간다.
 *  - 소계·합계는 반올림 전 값으로 더한 뒤 마지막에 반올림한다.
 */
export interface LegacyRoom {
  roomId: number;
  roomNumber: number;
  roomSpace: number;
}

export interface LegacyBill {
  billId: number;
  roomId: number;
  waterUsage: number;
  electricityUsage: number;
}

export interface LegacyCalcInput {
  buildingId: number;
  electricityTotalCost: number;
  electricityTotalUsage: number;
  waterTotalCost: number;
  waterSupplyCost: number;
  waterSewerCost: number;
}

export interface LegacyCalcOutput {
  /** roomNumber → 결과. 순서는 bills 순서(호수가 처음 나온 차례). */
  byRoomNumber: Map<number, BillCalc>;
  /** roomNumber → 금액을 기록할 대표 bill(그 호수의 첫 bill). */
  representativeBillId: Map<number, number>;
}

/** TV 수신료 등 전기 소계에 붙는 고정액(Go 동일). */
export const LEGACY_TV_FEE = 2500;

export function legacyCalculate(rooms: LegacyRoom[], bills: LegacyBill[], input: LegacyCalcInput): LegacyCalcOutput {
  const costPerKWh = input.electricityTotalCost / input.electricityTotalUsage;

  const roomMap = new Map<number, LegacyRoom>(); // roomId -> Room
  const roomNoSpace = new Map<number, number>(); // roomNumber -> roomSpace
  let totalSpace = 0;

  for (const room of rooms) {
    roomMap.set(room.roomId, room);
    if (!roomNoSpace.has(room.roomNumber)) {
      roomNoSpace.set(room.roomNumber, room.roomSpace);
      totalSpace += room.roomSpace;
    }
  }

  const byRoomNumber = new Map<number, BillCalc>();
  const representativeBillId = new Map<number, number>();
  let totalElectricityCommonCost = 0;
  let totalWaterUsage = 0;

  for (const bill of bills) {
    const room = roomMap.get(bill.roomId);
    if (!room) continue;
    const roomNumber = room.roomNumber;

    const existing = byRoomNumber.get(roomNumber);
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
      fb.buildingId = input.buildingId;
      fb.roomNumber = roomNumber;
      fb.calculateElectricityCost(bill.electricityUsage, costPerKWh);
      totalElectricityCommonCost += fb.electricityCost;
      totalWaterUsage += bill.waterUsage;
      byRoomNumber.set(roomNumber, fb);
      representativeBillId.set(roomNumber, bill.billId);
    }
  }

  for (const [roomNo, fBill] of byRoomNumber) {
    fBill.calculateElectricityCost(fBill.electricityUsage, costPerKWh);
    const totalCommonCost = fBill.calculateTotalCommonCost(input.electricityTotalCost, totalElectricityCommonCost);

    const roomSpace = roomNoSpace.get(roomNo) ?? 0;
    fBill.calculateElectricityCommonCost(totalCommonCost, roomSpace, totalSpace);

    fBill.calculateElectricityTax();
    fBill.calculateElectricityFund();
    fBill.calculateWaterCostSupply(input.waterSupplyCost, totalWaterUsage, fBill.waterUsage);
    fBill.calculateWaterCostSewer(input.waterSewerCost, totalWaterUsage, fBill.waterUsage);
    const commonWaterCost = fBill.calculateWaterCostCommon(input.waterTotalCost, input.waterSupplyCost, input.waterSewerCost);
    fBill.calculateWaterCommonCost(commonWaterCost, totalWaterUsage, fBill.waterUsage);
    fBill.calculateTotal(LEGACY_TV_FEE);

    fBill.roundMoney();
  }

  return { byRoomNumber, representativeBillId };
}
