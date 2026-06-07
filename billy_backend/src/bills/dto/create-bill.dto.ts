import { IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateBillDto {
  @IsOptional() @IsNumber() waterMeasure?: number;
  @IsOptional() @IsNumber() waterUsage?: number;
  @IsOptional() @IsNumber() waterBill?: number;
  @IsOptional() @IsNumber() electricityMeasure?: number;
  @IsOptional() @IsNumber() electricityUsage?: number;
  @IsOptional() @IsNumber() electricityBill?: number;
  @IsInt() roomId: number;
  @IsInt() floorId: number;
  @IsInt() buildingId: number;
  @IsString() chargeMonth: string;
}
