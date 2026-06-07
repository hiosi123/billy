import { IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateRoomDto {
  @IsInt()
  roomNumber: number;

  @IsOptional() @IsNumber() @Min(0)
  roomBaseCost?: number;

  @IsString()
  measureMachine: string;

  @IsString()
  roomName: string;

  @IsOptional() @IsNumber() @Min(0)
  roomSpace?: number;

  @IsOptional() @IsNumber() @Min(0)
  strictWater?: number;

  @IsOptional() @IsNumber() @Min(0)
  strictElectricity?: number;

  @IsOptional() @IsInt()
  measureNo?: number;

  @IsOptional() @IsNumber() @Min(0)
  measureMultiply?: number;

  @IsInt()
  floorId: number;

  @IsInt()
  buildingId: number;
}
