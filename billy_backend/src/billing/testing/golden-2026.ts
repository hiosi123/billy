import { LegacyBill, LegacyCalcInput, LegacyRoom } from '../legacy-calc';

/**
 * 운영 건물 1의 2026-08·09 실제 값(숫자만 — 이름 없음).
 * - 호실(계량기 행): room_id, room_number, room_space — 201·301 은 계량기 행이 셋이고 면적은 첫 행에만 있다.
 * - bills: 그달 bill_id·room_id·사용량(배수 반영된 값).
 * - input: 그달 calc_inputs(고지서 합계).
 * - expected: 운영 bills 에 저장된 호수별 전기·수도 합계와 같은 계산의 세부 항목(2026-11 로컬 재계산, 운영 저장값과 7/7 일치).
 * bill_id 는 로컬 재현 DB 기준이다(운영 id 와 다를 수 있음) — 대표 bill 확인에만 쓴다.
 */
export const BUILDING_ROOMS: LegacyRoom[] = [
  { roomId: 1, roomNumber: 101, roomSpace: 118.8 },
  { roomId: 2, roomNumber: 102, roomSpace: 49.9 },
  { roomId: 3, roomNumber: 103, roomSpace: 197.6 },
  { roomId: 4, roomNumber: 201, roomSpace: 251.9 },
  { roomId: 5, roomNumber: 201, roomSpace: 0 },
  { roomId: 6, roomNumber: 201, roomSpace: 0 },
  { roomId: 7, roomNumber: 301, roomSpace: 391.7 },
  { roomId: 8, roomNumber: 301, roomSpace: 0 },
  { roomId: 9, roomNumber: 301, roomSpace: 0 },
  { roomId: 10, roomNumber: 401, roomSpace: 391.7 },
  { roomId: 11, roomNumber: 501, roomSpace: 391.7 },
];

/** 계량기 배수·고정 사용량(새 엔진이 쓰는 계량기 정보). */
export const BUILDING_METERS = {
  multiplyByRoomId: { 7: 25, 8: 25, 9: 25, 10: 25, 11: 25 } as Record<number, number>,
  strictWaterByRoomId: { 1: 4, 2: 1 } as Record<number, number>,
};

type Money = {
  electricityCost: number;
  electricityCostCommon: number;
  electricityCostTax: number;
  electricityCostFund: number;
  electricityCostTotal: number;
  waterCostSupply: number;
  waterCostSewer: number;
  waterCostCommon: number;
  waterCostTotal: number;
  totalCost: number;
};

interface GoldenMonth {
  input: LegacyCalcInput;
  bills: LegacyBill[];
  expected: Record<string, { money: Money; electricityUsage: number; waterUsage: number }>;
}

/** [전기사용분, 공용전기, 부가세, 기금, 전기합계, 상수도, 하수도, 공용수도, 수도합계, 총액, 전기사용량, 수도사용량] */
type Row = [number, number, number, number, number, number, number, number, number, number, number, number];

const toExpected = (rows: Record<string, Row>): GoldenMonth['expected'] =>
  Object.fromEntries(
    Object.entries(rows).map(([k, r]) => [
      k,
      {
        money: {
          electricityCost: r[0],
          electricityCostCommon: r[1],
          electricityCostTax: r[2],
          electricityCostFund: r[3],
          electricityCostTotal: r[4],
          waterCostSupply: r[5],
          waterCostSewer: r[6],
          waterCostCommon: r[7],
          waterCostTotal: r[8],
          totalCost: r[9],
        },
        electricityUsage: r[10],
        waterUsage: r[11],
      },
    ]),
  );

/** [bill_id, room_id, 수도사용량, 전기사용량] */
const toBills = (rows: [number, number, number, number][]): LegacyBill[] =>
  rows.map(([billId, roomId, waterUsage, electricityUsage]) => ({ billId, roomId, waterUsage, electricityUsage }));

export const MONTHS: Record<string, GoldenMonth> = {
  '202608': {
    input: {
      buildingId: 1,
      electricityTotalCost: 4877469,
      electricityTotalUsage: 25208,
      waterTotalCost: 914980,
      waterSupplyCost: 374460,
      waterSewerCost: 493690,
    },
    bills: toBills([
      [34, 1, 4, 1308.9], [35, 2, 1, 868.8], [36, 3, 6, 5185.6], [37, 4, 4, 31.2], [38, 5, 0, 2977.6], [39, 6, 0, 0],
      [40, 7, 10, 4415.75], [41, 8, 23, 0], [42, 9, 0, 0], [43, 10, 19, 3030.25], [44, 11, 118, 4702],
    ]),
    expected: toExpected({
      '101': [253258, 34453, 28771, 7768, 326750, 8096, 10674, 1013, 19783, 346534, 1308.9, 4],
      '102': [168103, 14472, 18257, 4930, 208262, 2024, 2669, 253, 4946, 213208, 868.8, 1],
      '103': [1003356, 57306, 106066, 28638, 1197867, 12145, 16012, 1519, 29675, 1227542, 5185.6, 6],
      '201': [582169, 73054, 65522, 17691, 740937, 8096, 10674, 1013, 19783, 760720, 3008.8, 4],
      '301': [854399, 113598, 96800, 26136, 1093432, 66796, 88064, 8353, 163213, 1256645, 4415.75, 33],
      '401': [586320, 113598, 69992, 18898, 791307, 38458, 50703, 4810, 93971, 885278, 3030.25, 19],
      '501': [909785, 113598, 102338, 27631, 1155852, 238845, 314894, 29870, 583609, 1739461, 4702, 118],
    }),
  },
  '202609': {
    input: {
      buildingId: 1,
      electricityTotalCost: 3796266,
      electricityTotalUsage: 20424,
      waterTotalCost: 682770,
      waterSupplyCost: 289420,
      waterSewerCost: 365710,
    },
    bills: toBills([
      [45, 1, 4, 1085], [46, 2, 1, 736.8], [47, 3, 4, 3726.2], [48, 4, 4, 24.1], [49, 5, 5, 2478.2], [50, 6, 1, 0],
      [51, 7, 4, 3440.75], [52, 8, 14, 0], [53, 9, 0, 0], [54, 10, 32, 2235.75], [55, 11, 118, 3803],
    ]),
    expected: toExpected({
      '101': [201672, 35638, 23731, 6407, 269948, 6191, 7823, 591, 14605, 284553, 1085, 4],
      '102': [136951, 14969, 15192, 4102, 173714, 1548, 1956, 148, 3651, 177365, 736.8, 1],
      '103': [692599, 59276, 75188, 20301, 849863, 6191, 7823, 591, 14605, 864468, 3726.2, 4],
      '201': [465109, 75565, 54067, 14598, 611840, 15477, 19557, 1478, 36512, 648352, 2502.3, 10],
      '301': [639542, 117502, 75704, 20440, 855688, 27859, 35202, 2661, 65721, 921409, 3440.75, 18],
      '401': [415565, 117502, 53307, 14393, 603267, 49526, 62581, 4730, 116838, 720104, 2235.75, 32],
      '501': [706874, 117502, 82438, 22258, 931572, 182629, 230769, 17441, 430839, 1362411, 3803, 118],
    }),
  },
};
