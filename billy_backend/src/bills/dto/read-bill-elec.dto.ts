import { IsArray, IsInt, IsOptional, IsString } from 'class-validator';

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

  /** RAG용: 이 건물의 직전 정답 예시를 few-shot 으로 함께 보내기 위함(선택). */
  @IsOptional()
  @IsInt()
  buildingId?: number;

  /** 추출 중인 달(YYYYMM). 예시에서 자기 자신 제외용(선택). */
  @IsOptional()
  @IsString()
  chargeMonth?: string;
}
