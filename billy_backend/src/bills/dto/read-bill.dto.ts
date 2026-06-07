import { IsIn, IsOptional, IsString } from 'class-validator';

/** 공공요금 고지서 사진 OCR 요청 (관리비 계산 합계 자동 입력용). */
export class ReadBillDto {
  /** base64 인코딩 이미지 (data: 접두사 제외). */
  @IsString()
  image: string;

  /** 고지서 종류. */
  @IsIn(['water', 'electricity'])
  type: 'water' | 'electricity';

  /** 이미지 MIME 타입(기본 image/jpeg). */
  @IsOptional()
  @IsString()
  mediaType?: string;
}
