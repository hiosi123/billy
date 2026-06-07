import { IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

export class BillHistoryDto {
  @IsInt() roomNumber: number;
  @IsString() chargeMonth: string;

  @IsOptional() @IsNumber() electricityCost?: number;
  @IsOptional() @IsNumber() electricityCostCommon?: number;
  @IsOptional() @IsNumber() electricityCostTax?: number;
  @IsOptional() @IsNumber() electricityCostFund?: number;
  @IsOptional() @IsNumber() electricityCostTotal?: number;
  @IsOptional() @IsNumber() waterCostSupply?: number;
  @IsOptional() @IsNumber() waterCostSewer?: number;
  @IsOptional() @IsNumber() waterCostCommon?: number;
  @IsOptional() @IsNumber() waterCostTotal?: number;
  @IsOptional() @IsNumber() totalCost?: number;

  @IsInt() buildingId: number;
}
