-- ─────────────────────────────────────────────────────────────────────────
-- Billy 스키마 (PostgreSQL) + 샘플 시드
--
-- 사용:
--   createdb billy            # 또는 psql 에서 CREATE DATABASE billy;
--   psql -d billy -f sql/schema.sql
--
-- 한글 데이터는 DB 인코딩이 UTF8 이어야 한다(기본값). DROP 후 재생성하므로
-- 신규/초기화 환경에서만 실행할 것.
-- ─────────────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS bill_histories CASCADE;
DROP TABLE IF EXISTS bills CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS floors CASCADE;
DROP TABLE IF EXISTS building_fees CASCADE;
DROP TABLE IF EXISTS buildings CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- updated_at 자동 갱신 트리거 함수 (MySQL의 ON UPDATE CURRENT_TIMESTAMP 대체)
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── users ────────────────────────────────────────────────────────────────
CREATE TABLE users (
  user_id     SERIAL PRIMARY KEY,
  username    VARCHAR(64) NOT NULL UNIQUE,
  password    VARCHAR(255) NOT NULL,            -- SHA-256 hex
  role        VARCHAR(16) NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin','manager','viewer')),
  created_at  TIMESTAMP NOT NULL DEFAULT now(),
  updated_at  TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_role ON users(role);
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── buildings ────────────────────────────────────────────────────────────
CREATE TABLE buildings (
  building_id      SERIAL PRIMARY KEY,
  building_name    VARCHAR(255) NOT NULL,
  building_address VARCHAR(255) NOT NULL,
  building_floors  INT NOT NULL DEFAULT 1,
  elevator         INT DEFAULT 0,
  owner            VARCHAR(255) NOT NULL,
  user_id          INT REFERENCES users(user_id) ON DELETE SET NULL,
  created_at       TIMESTAMP NOT NULL DEFAULT now(),
  updated_at       TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_building_name ON buildings(building_name);
CREATE INDEX idx_building_owner ON buildings(owner);
CREATE INDEX idx_building_user ON buildings(user_id);
CREATE TRIGGER trg_buildings_updated BEFORE UPDATE ON buildings FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── floors ───────────────────────────────────────────────────────────────
CREATE TABLE floors (
  floor_id    SERIAL PRIMARY KEY,
  floor       INT NOT NULL,
  floor_space NUMERIC(10,2) NOT NULL DEFAULT 0,
  building_id INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  created_at  TIMESTAMP NOT NULL DEFAULT now(),
  updated_at  TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT unique_building_floor UNIQUE (building_id, floor)
);
CREATE INDEX idx_floor_building ON floors(building_id, floor);
CREATE TRIGGER trg_floors_updated BEFORE UPDATE ON floors FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── rooms ────────────────────────────────────────────────────────────────
CREATE TABLE rooms (
  room_id            SERIAL PRIMARY KEY,
  room_number        INT NOT NULL,
  room_base_cost     NUMERIC(10,2) NOT NULL DEFAULT 0,
  measure_machine    VARCHAR(64) NOT NULL,
  room_name          VARCHAR(255) NOT NULL,
  room_space         NUMERIC(10,2) NOT NULL DEFAULT 0,
  measure_no         INT NOT NULL DEFAULT 0,
  strict_water       NUMERIC(10,2) NOT NULL DEFAULT 0,
  strict_electricity NUMERIC(10,2) NOT NULL DEFAULT 0,
  measure_multiply   NUMERIC(10,2) NOT NULL DEFAULT 1,
  floor_id           INT NOT NULL REFERENCES floors(floor_id) ON DELETE CASCADE,
  building_id        INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  created_at         TIMESTAMP NOT NULL DEFAULT now(),
  updated_at         TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_room_floor ON rooms(floor_id, room_number);
CREATE INDEX idx_room_building_number ON rooms(building_id, room_number);
CREATE INDEX idx_room_name ON rooms(room_name);
CREATE TRIGGER trg_rooms_updated BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── bills ────────────────────────────────────────────────────────────────
CREATE TABLE bills (
  bill_id             SERIAL PRIMARY KEY,
  water_measure       NUMERIC(10,2) DEFAULT 0,
  water_usage         NUMERIC(10,2) DEFAULT 0,
  water_bill          NUMERIC(10,2) DEFAULT 0,
  electricity_measure NUMERIC(10,2) DEFAULT 0,
  electricity_usage   NUMERIC(10,2) DEFAULT 0,
  electricity_bill    NUMERIC(10,2) DEFAULT 0,
  room_id             INT NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,
  floor_id            INT NOT NULL REFERENCES floors(floor_id) ON DELETE CASCADE,
  building_id         INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  charge_month        VARCHAR(6) NOT NULL DEFAULT '',
  created_at          TIMESTAMP NOT NULL DEFAULT now(),
  updated_at          TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_bill_month_building ON bills(charge_month, building_id);
CREATE INDEX idx_bill_room ON bills(room_id);
CREATE INDEX idx_bill_floor ON bills(floor_id);
CREATE INDEX idx_bill_building ON bills(building_id);
CREATE TRIGGER trg_bills_updated BEFORE UPDATE ON bills FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── bill_histories ───────────────────────────────────────────────────────
CREATE TABLE bill_histories (
  bill_history_id         SERIAL PRIMARY KEY,
  room_number             INT NOT NULL,
  charge_month            VARCHAR(6) NOT NULL DEFAULT '',
  electricity_cost        NUMERIC(10,2) DEFAULT 0,
  electricity_cost_common NUMERIC(10,2) DEFAULT 0,
  electricity_cost_tax    NUMERIC(10,2) DEFAULT 0,
  electricity_cost_fund   NUMERIC(10,2) DEFAULT 0,
  electricity_cost_total  NUMERIC(10,2) DEFAULT 0,
  water_cost_supply       NUMERIC(10,2) DEFAULT 0,
  water_cost_sewer        NUMERIC(10,2) DEFAULT 0,
  water_cost_common       NUMERIC(10,2) DEFAULT 0,
  water_cost_total        NUMERIC(10,2) DEFAULT 0,
  total_cost              NUMERIC(10,2) DEFAULT 0,
  building_id             INT NOT NULL,
  created_at              TIMESTAMP NOT NULL DEFAULT now(),
  updated_at              TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_bh_month_building ON bill_histories(charge_month, building_id);
CREATE INDEX idx_bh_room_number ON bill_histories(room_number);
CREATE TRIGGER trg_bh_updated BEFORE UPDATE ON bill_histories FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── building_fees (건물당 1행) ────────────────────────────────────────────
CREATE TABLE building_fees (
  building_id                INT PRIMARY KEY,
  general_management_fee     NUMERIC(10,2) DEFAULT 0,
  public_inspection_fee      NUMERIC(10,2) DEFAULT 0,
  fire_management_fee        NUMERIC(10,2) DEFAULT 0,
  elevator_maintenance_fee   NUMERIC(10,2) DEFAULT 0,
  septic_tank_management_fee NUMERIC(10,2) DEFAULT 0,
  electrical_management_fee  NUMERIC(10,2) DEFAULT 0,
  parking_management_fee     NUMERIC(10,2) DEFAULT 0,
  created_at                 TIMESTAMP NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_fees_updated BEFORE UPDATE ON building_fees FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────
-- 샘플 시드 (기존 MySQL 시드와 동일 데이터)
-- 비밀번호: sha256("1234") = 03ac6742...  (계정 admin / 비번 1234)
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO users (user_id, username, password, role) VALUES
(1, 'admin', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'admin');
SELECT setval('users_user_id_seq', (SELECT MAX(user_id) FROM users));

INSERT INTO buildings (building_name, building_address, building_floors, elevator, owner, user_id) VALUES
('새아여성의원', '부산시 반여2동', 5, 1, '신창열', 1);

INSERT INTO floors (floor, floor_space, building_id) VALUES
(1, 366.29, 1),
(2, 255.98, 1),
(3, 391.74, 1),
(4, 391.74, 1),
(5, 391.74, 1);

INSERT INTO rooms (room_number, room_base_cost, measure_machine, room_name, room_space, strict_water, measure_multiply, floor_id, building_id) VALUES
(101, 332850.0, 'KTF', 'KTF', 118.80, 4, 1, 1, 1),
(102, 237890.0, '약국', '약국', 49.85, 1, 1, 1, 1),
(103, 150000.0, '행복마당', '행복마당', 197.64, 0, 1, 1, 1),
(201, 105920.0, '천리안안과-1', '천리안안과', 255.98, 0, 1, 2, 1),
(201, 105920.0, '천리안안과-2', '천리안안과', 255.98, 0, 1, 2, 1),
(201, 105920.0, '천리안안과-3', '천리안안과', 255.98, 0, 1, 2, 1),
(301, 193800.0, '고려신경-1', '고려신경', 391.74, 0, 25, 3, 1),
(301, 193800.0, '고려신경-2', '고려신경', 391.74, 0, 25, 3, 1),
(301, 193800.0, '고려신경-3', '고려신경', 391.74, 0, 25, 3, 1),
(401, 9740.0, '새아여성의원', '새아여성의원', 391.74, 0, 25, 4, 1),
(501, 169090.0, '사랑채', '사랑채', 391.74, 0, 25, 5, 1);

INSERT INTO bills (water_measure, water_usage, electricity_measure, electricity_usage, charge_month, room_id, floor_id, building_id) VALUES
(0, 4, 35922.2, 722, '202506', 1, 1, 1),
(0, 1, 25807, 750, '202506', 2, 1, 1),
(541, 10, 74434.3, 1986, '202506', 3, 1, 1),
(819, 3, 11753.4, 23, '202506', 4, 2, 1),
(2520, 7, 99265, 2008, '202506', 5, 2, 1),
(2606, 1, 0, 0, '202506', 6, 2, 1),
(6277, 13, 4849.53, 2650, '202506', 7, 3, 1),
(6506, 30, 0, 0, '202506', 8, 3, 1),
(98, 0, 0, 0, '202506', 9, 3, 1),
(5834, 23, 3228.81, 1385, '202506', 10, 4, 1),
(12450, 123, 4139.27, 2913, '202506', 11, 5, 1),
(0, 4, 36748.2, 826, '202507', 1, 1, 1),
(0, 1, 26710, 903, '202507', 2, 1, 1),
(565, 24, 78228.3, 3794, '202507', 3, 1, 1),
(824, 5, 11700, -53, '202507', 4, 2, 1),
(2527, 7, 101856.5, 2594, '202507', 5, 2, 1),
(2607, 1, 0, 0, '202507', 6, 2, 1),
(6299, 22, 4997.14, 3691, '202507', 7, 3, 1),
(6551, 45, 0, 0, '202507', 8, 3, 1),
(98, 0, 0, 0, '202507', 9, 3, 1),
(5860, 26, 3316.35, 2189, '202507', 10, 4, 1),
(12584, 134, 4286.51, 3681, '202507', 11, 5, 1);

INSERT INTO building_fees (building_id, general_management_fee, public_inspection_fee, fire_management_fee, elevator_maintenance_fee, septic_tank_management_fee, electrical_management_fee, parking_management_fee) VALUES
(1, 1834920, 1160817, 224000, 220000, 236020, 259720, 382418);
