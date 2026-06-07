import { IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class UpdateRoomDto {
  @IsOptional() @IsInt() roomNumber?: number;
  @IsOptional() @IsNumber() @Min(0) roomBaseCost?: number;
  @IsOptional() @IsString() measureMachine?: string;
  @IsOptional() @IsString() roomName?: string;
  @IsOptional() @IsNumber() @Min(0) roomSpace?: number;
  @IsOptional() @IsNumber() @Min(0) strictWater?: number;
  @IsOptional() @IsNumber() @Min(0) strictElectricity?: number;
  @IsOptional() @IsInt() measureNo?: number;
  @IsOptional() @IsNumber() @Min(0) measureMultiply?: number;
  @IsOptional() @IsInt() floorId?: number;
  @IsOptional() @IsInt() buildingId?: number;
}
