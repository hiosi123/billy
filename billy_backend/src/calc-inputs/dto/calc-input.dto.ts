import { IsArray, IsInt, IsNumber, IsOptional, IsString } from 'class-validator';

/** 관리비 계산 입력값 저장 요청. */
export class CalcInputDto {
  @IsInt() buildingId: number;
  @IsString() chargeMonth: string;

  @IsOptional() @IsNumber() electricityTotalCost?: number;
  @IsOptional() @IsNumber() electricityTotalUsage?: number;
  @IsOptional() @IsNumber() waterTotalCost?: number;
  @IsOptional() @IsNumber() waterTotalUsage?: number;
  @IsOptional() @IsNumber() waterSupplyCost?: number;
  @IsOptional() @IsNumber() waterSewerCost?: number;

  /** 수도 고지서 사진(base64). */
  @IsOptional() @IsString() waterPhoto?: string | null;

  /** 전기 고지서 사진들(base64 배열). */
  @IsOptional() @IsArray() @IsString({ each: true }) elecPhotos?: string[] | null;
}
