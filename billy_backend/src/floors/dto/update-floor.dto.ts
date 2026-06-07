import { IsInt, IsNumber, IsOptional, Min } from 'class-validator';

export class UpdateFloorDto {
  @IsOptional() @IsInt() floor?: number;
  @IsOptional() @IsNumber() @Min(0) floorSpace?: number;
  @IsOptional() @IsInt() buildingId?: number;
}
