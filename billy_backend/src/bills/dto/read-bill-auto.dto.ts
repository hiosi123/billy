import { IsOptional, IsString } from 'class-validator';

/** 고지서 사진 OCR(수도/전기 자동 판별) 요청. type 없이 이미지만 보낸다. */
export class ReadBillAutoDto {
  /** base64 인코딩 이미지 (data: 접두사 제외). */
  @IsString()
  image: string;

  /** 이미지 MIME 타입(기본 image/jpeg). */
  @IsOptional()
  @IsString()
  mediaType?: string;
}
