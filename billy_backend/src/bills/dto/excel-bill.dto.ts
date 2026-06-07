import { IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

/** 엑셀 명세서 생성용 한 호실의 계산 결과(MakeBillExcel 입력). */
export class ExcelBillDto {
  @IsInt() BuildingId: number;
  @IsInt() RoomNumber: number;

  /** 사용월(YYYYMM). 고지서 날짜는 이 값 +1개월로 표기된다(5월 고지서=4월 사용분). */
  @IsOptional() @IsString() ChargeMonth?: string;

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
