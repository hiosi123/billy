import { IsInt, IsNumber, IsString } from 'class-validator';

/** 검침값 입력(InsertMeasure)용. 기존 Go 의 Usage 구조체와 동일 필드. */
export class UsageDto {
  @IsInt() BuildingId: number;
  @IsInt() FloorId: number;
  @IsInt() RoomId: number;
  @IsNumber() WaterMeasure: number;
  @IsNumber() ElectricityMeasure: number;
  @IsString() ChargeMonth: string; // YYYYMM
}
