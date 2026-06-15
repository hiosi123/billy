-- 검침(계량기) 사진 S3 URL 저장 컬럼. (추가형 — 기존 데이터 영향 없음)
ALTER TABLE bills ADD COLUMN IF NOT EXISTS water_meter_photo TEXT;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS electricity_meter_photo TEXT;
