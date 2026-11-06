import { legacyCalculate, LegacyBill, LegacyCalcInput, LegacyRoom } from './legacy-calc';
import { BUILDING_ROOMS, MONTHS } from './testing/golden-2026';

/**
 * 정답지 고정: 운영에 저장된 2026-08·09 요금(호수별 전기·수도 합계)과
 * 그때의 세부 항목을 기존 계산이 그대로 내는지 확인한다.
 * 이 테스트가 깨지면 '기존 방식' 결과가 바뀐 것이다 — 고치기 전에 이유부터 찾을 것.
 */
describe('legacyCalculate — 운영 2026 정답지', () => {
  for (const month of Object.keys(MONTHS)) {
    const { input, bills, expected } = MONTHS[month];

    it(`${month}: 호수별 전기·수도 세부 항목이 운영 저장값과 원 단위까지 같다`, () => {
      const { byRoomNumber } = legacyCalculate(BUILDING_ROOMS, bills, input);
      expect([...byRoomNumber.keys()].sort()).toEqual(Object.keys(expected).map(Number).sort());
      for (const [roomNo, e] of Object.entries(expected)) {
        const r = byRoomNumber.get(Number(roomNo))!;
        expect({
          electricityCost: r.electricityCost,
          electricityCostCommon: r.electricityCostCommon,
          electricityCostTax: r.electricityCostTax,
          electricityCostFund: r.electricityCostFund,
          electricityCostTotal: r.electricityCostTotal,
          waterCostSupply: r.waterCostSupply,
          waterCostSewer: r.waterCostSewer,
          waterCostCommon: r.waterCostCommon,
          waterCostTotal: r.waterCostTotal,
          totalCost: r.totalCost,
        }).toEqual(e.money);
        expect(r.electricityUsage).toBeCloseTo(e.electricityUsage, 6);
        expect(r.waterUsage).toBeCloseTo(e.waterUsage, 6);
      }
    });
  }

  it('대표 bill 은 그 호수의 첫 bill 이다(금액을 기록하는 행)', () => {
    const { representativeBillId } = legacyCalculate(BUILDING_ROOMS, MONTHS['202609'].bills, MONTHS['202609'].input);
    expect(representativeBillId.get(201)).toBe(48); // 201 의 첫 계량기 행(room 4)
    expect(representativeBillId.get(301)).toBe(51); // 301 의 첫 계량기 행(room 7)
  });

  it('면적은 같은 호수의 첫 행 값 — 행 순서가 바뀌면 결과가 바뀐다(알려진 동작)', () => {
    const rooms: LegacyRoom[] = BUILDING_ROOMS.map((r) => ({ ...r }));
    const swapped = [rooms[4], rooms[3], ...rooms.filter((_, i) => i !== 3 && i !== 4)]; // 201 의 둘째 행(면적 0)이 먼저
    const bills: LegacyBill[] = MONTHS['202609'].bills;
    const input: LegacyCalcInput = MONTHS['202609'].input;
    const normal = legacyCalculate(rooms, bills, input).byRoomNumber.get(201)!;
    const shuffled = legacyCalculate(swapped, bills, input).byRoomNumber.get(201)!;
    expect(normal.electricityCostCommon).toBeGreaterThan(0);
    expect(shuffled.electricityCostCommon).toBe(0);
  });
});
