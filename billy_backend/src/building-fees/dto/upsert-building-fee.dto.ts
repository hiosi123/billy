import { IsInt, IsNumber, IsOptional, Min } from 'class-validator';

export class UpsertBuildingFeeDto {
  @IsInt()
  buildingId: number;

  @IsOptional() @IsNumber() @Min(0) generalManagementFee?: number;
  @IsOptional() @IsNumber() @Min(0) publicInspectionFee?: number;
  @IsOptional() @IsNumber() @Min(0) fireManagementFee?: number;
  @IsOptional() @IsNumber() @Min(0) elevatorMaintenanceFee?: number;
  @IsOptional() @IsNumber() @Min(0) septicTankManagementFee?: number;
  @IsOptional() @IsNumber() @Min(0) electricalManagementFee?: number;
  @IsOptional() @IsNumber() @Min(0) parkingManagementFee?: number;
}
