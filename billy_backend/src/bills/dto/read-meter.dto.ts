import { IsIn, IsNumber, IsOptional, IsString } from 'class-validator';

/** 계량기 사진 OCR 요청. */
export class ReadMeterDto {
  /** base64 인코딩된 이미지 데이터 (data: 접두사 제외). */
  @IsString()
  image: string;

  /** 계량기 종류. */
  @IsIn(['water', 'electricity'])
  type: 'water' | 'electricity';

  /** 지난달 검침값(있으면 자릿수/범위 힌트로 사용). */
  @IsOptional()
  @IsNumber()
  lastValue?: number;

  /** 이미지 MIME 타입(기본 image/jpeg). */
  @IsOptional()
  @IsString()
  mediaType?: string;
}
