import { IsInt, IsNumber, IsString } from 'class-validator';

/** 관리비 계산(CalculateBill) 요청. 기존 Go 의 CalculateBillReq 와 동일. */
export class CalculateBillDto {
  @IsInt() BuildingId: number;
  @IsString() Month: string; // YYYYMM
  @IsNumber() ElectricityTotalCost: number; // 전체 전기요금
  @IsNumber() WaterTotalCost: number; // 전체 수도요금
  @IsNumber() ElectricityTotalUsage: number; // 전체 전기 사용량
  @IsNumber() WaterTotalUsage: number; // 전체 수도 사용량
  @IsNumber() WaterSupplyCost: number; // 상수도 요금
  @IsNumber() WaterSewerCost: number; // 하수도 요금
}
