import { ValueTransformer } from 'typeorm';

/**
 * PostgreSQL numeric/decimal 컬럼은 pg 드라이버가 문자열("6.50")로 반환한다.
 * 직접 산술에 쓰면 NaN/문자열 연결 버그가 나므로 읽을 때 number 로 변환한다.
 * (ddiding 플레이북의 #1 교훈: decimal → String 안전 파싱)
 */
export const DecimalTransformer: ValueTransformer = {
  to: (value?: number | null) => value,
  from: (value?: string | null) => (value === null || value === undefined ? value : parseFloat(value)),
};
