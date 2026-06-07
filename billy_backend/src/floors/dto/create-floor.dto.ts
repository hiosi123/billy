import { IsInt, IsNumber, IsOptional, Min } from 'class-validator';

export class CreateFloorDto {
  @IsInt()
  floor: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  floorSpace?: number;

  @IsInt()
  buildingId: number;
}
