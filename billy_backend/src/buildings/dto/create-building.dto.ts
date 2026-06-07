import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateBuildingDto {
  @IsString()
  buildingName: string;

  @IsString()
  buildingAddress: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  buildingFloors?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  elevator?: number;

  @IsString()
  owner: string;
}
