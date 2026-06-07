-- ─────────────────────────────────────────────────────────────────────────
-- Billy 추가형 마이그레이션 #001  (PostgreSQL)
--
-- 목적: 이미 운영 중인 Postgres DB에 백엔드가 필요로 하는 스키마를
--       "기존 데이터를 건드리지 않고" 멱등(idempotent)하게 보강한다.
--       신규 환경은 schema.sql 로 만들면 되고, 이 파일은 기존 DB 보강용.
--
-- ⚠️ 원칙: DROP/TRUNCATE/타입변경 금지. 오직 "없을 때만 추가".
--          TypeORM synchronize 는 운영에서 항상 false.
--
-- 실행: psql -d <db> -f sql/migrations/001_additive.sql
-- ─────────────────────────────────────────────────────────────────────────

-- 1) buildings.user_id : 건물 소유자 매핑 (구버전 DB 대비)
ALTER TABLE buildings ADD COLUMN IF NOT EXISTS user_id INT;
CREATE INDEX IF NOT EXISTS idx_building_user ON buildings(user_id);

-- 2) 조회 성능 인덱스
CREATE INDEX IF NOT EXISTS idx_bill_month_building ON bills(charge_month, building_id);
CREATE INDEX IF NOT EXISTS idx_room_building_number ON rooms(building_id, room_number);
CREATE INDEX IF NOT EXISTS idx_bh_month_building ON bill_histories(charge_month, building_id);

-- 3) updated_at 자동 갱신 트리거 함수가 없으면 생성 (schema.sql 미적용 DB 대비)
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
