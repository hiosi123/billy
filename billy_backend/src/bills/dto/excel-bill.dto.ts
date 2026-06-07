import { IsInt, IsNumber, IsOptional } from 'class-validator';

/** 엑셀 명세서 생성용 한 호실의 계산 결과(MakeBillExcel 입력). */
export class ExcelBillDto {
  @IsInt() BuildingId: number;
  @IsInt() RoomNumber: number;

  @IsOptional() @IsNumber() ElectricityCost?: number;
  @IsOptional() @IsNumber() ElectricityCostCommon?: number;
  @IsOptional() @IsNumber() ElectricityCostTax?: number;
  @IsOptional() @IsNumber() ElectricityCostFund?: number;
  @IsOptional() @IsNumber() ElectricityCostTotal?: number;
  @IsOptional() @IsNumber() WaterCostSupply?: number;
  @IsOptional() @IsNumber() WaterCostSewer?: number;
  @IsOptional() @IsNumber() WaterCostCommon?: number;
  @IsOptional() @IsNumber() WaterCostTotal?: number;
  @IsOptional() @IsNumber() TotalCost?: number;
}
