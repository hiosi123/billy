import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class UpdateBuildingDto {
  @IsOptional() @IsString() buildingName?: string;
  @IsOptional() @IsString() buildingAddress?: string;
  @IsOptional() @IsInt() @Min(1) buildingFloors?: number;
  @IsOptional() @IsInt() @Min(0) elevator?: number;
  @IsOptional() @IsString() owner?: string;
}
