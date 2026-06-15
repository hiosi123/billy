import { IsArray, IsOptional, IsString } from 'class-validator';

/** 전기 고지서 여러 장(청구서+내역서) OCR 요청. base64 이미지 배열. */
export class ReadBillElecDto {
  /** base64 인코딩 이미지 배열(data: 접두사 제외). 보통 2장. */
  @IsArray()
  @IsString({ each: true })
  images: string[];

  /** 이미지 MIME 타입(기본 image/jpeg). 모든 이미지 공통. */
  @IsOptional()
  @IsString()
  mediaType?: string;
}
