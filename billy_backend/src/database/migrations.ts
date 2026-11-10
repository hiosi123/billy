/**
 * 스키마 마이그레이션 — 서버가 켜질 때 MigrationService 가 순서대로 한 번씩 적용한다(schema_migrations 에 기록).
 *
 * 규칙(운영 DB 를 지키기 위해):
 *  - **추가만.** CREATE ... IF NOT EXISTS / 새 테이블. 기존 테이블의 컬럼·타입·데이터는 바꾸지 않는다.
 *  - 다시 돌려도 같은 결과(멱등). 백필은 비어 있을 때만(ON CONFLICT DO NOTHING).
 *  - 기존 엔티티(rooms·calc_inputs 등)는 새 컬럼에 기대지 않는다 — v2 마이그레이션이 실패해도 기존 화면은 돈다.
 * 001~003 은 예전에 psql 로 손으로 넣던 sql/migrations/*.sql 과 같은 내용(운영엔 이미 있어 아무 일도 안 한다).
 */
export interface SqlMigration {
  name: string;
  sql: string;
}

const m001 = `
ALTER TABLE buildings ADD COLUMN IF NOT EXISTS user_id INT;
CREATE INDEX IF NOT EXISTS idx_building_user ON buildings(user_id);
CREATE INDEX IF NOT EXISTS idx_bill_month_building ON bills(charge_month, building_id);
CREATE INDEX IF NOT EXISTS idx_room_building_number ON rooms(building_id, room_number);
CREATE INDEX IF NOT EXISTS idx_bh_month_building ON bill_histories(charge_month, building_id);
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $fn$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;
`;

const m002 = `
CREATE TABLE IF NOT EXISTS calc_inputs (
  calc_input_id            SERIAL PRIMARY KEY,
  building_id              INTEGER       NOT NULL,
  charge_month             VARCHAR(6)    NOT NULL DEFAULT '',
  electricity_total_cost   NUMERIC(14,2) NOT NULL DEFAULT 0,
  electricity_total_usage  NUMERIC(14,2) NOT NULL DEFAULT 0,
  water_total_cost         NUMERIC(14,2) NOT NULL DEFAULT 0,
  water_total_usage        NUMERIC(14,2) NOT NULL DEFAULT 0,
  water_supply_cost        NUMERIC(14,2) NOT NULL DEFAULT 0,
  water_sewer_cost         NUMERIC(14,2) NOT NULL DEFAULT 0,
  water_photo              TEXT,
  elec_photos              TEXT,
  created_at               TIMESTAMP     NOT NULL DEFAULT now(),
  updated_at               TIMESTAMP     NOT NULL DEFAULT now(),
  CONSTRAINT uq_calc_inputs_building_month UNIQUE (building_id, charge_month)
);
`;

const m003 = `
ALTER TABLE bills ADD COLUMN IF NOT EXISTS water_meter_photo TEXT;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS electricity_meter_photo TEXT;
`;

/**
 * v2: 호실(청구 단위)·호실-계량기 연결·요금표·월 입력·확정 명세서·건물 설정·건물 멤버.
 * 호실은 기존 계량기 행(rooms)을 호수로 묶어 만든다 — 대표 행 = 그 호수에서 room_id 가 가장 작은 행
 * (지금 계산이 쓰는 '첫 행'과 같다). 이후 면적·기본료는 호실에서 관리한다.
 */
const m004 = `
CREATE TABLE IF NOT EXISTS units (
  unit_id     SERIAL PRIMARY KEY,
  building_id INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  floor_id    INT REFERENCES floors(floor_id) ON DELETE SET NULL,
  unit_number INT NOT NULL,
  name        VARCHAR(255) NOT NULL DEFAULT '',
  area        NUMERIC(12,2) NOT NULL DEFAULT 0,
  base_cost   NUMERIC(14,2) NOT NULL DEFAULT 0,
  sort        INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMP NOT NULL DEFAULT now(),
  updated_at  TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_units_building_number UNIQUE (building_id, unit_number)
);

CREATE TABLE IF NOT EXISTS unit_meters (
  room_id    INT PRIMARY KEY REFERENCES rooms(room_id) ON DELETE CASCADE,
  unit_id    INT NOT NULL REFERENCES units(unit_id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_unit_meters_unit ON unit_meters(unit_id);

-- 옛 데이터에 짝 없는 참조(지워진 건물·층)가 있어도 실패하지 않게: 건물은 있는 것만, 층은 없으면 NULL.
INSERT INTO units (building_id, floor_id, unit_number, name, area, base_cost, sort)
SELECT r.building_id, (SELECT fl.floor_id FROM floors fl WHERE fl.floor_id = r.floor_id),
       r.room_number, COALESCE(r.room_name, ''), COALESCE(r.room_space, 0), COALESCE(r.room_base_cost, 0), r.room_number
FROM rooms r
JOIN (SELECT MIN(room_id) AS room_id FROM rooms GROUP BY building_id, room_number) f ON f.room_id = r.room_id
JOIN buildings b ON b.building_id = r.building_id
ORDER BY r.room_id
ON CONFLICT (building_id, unit_number) DO NOTHING;

INSERT INTO unit_meters (room_id, unit_id)
SELECT r.room_id, u.unit_id FROM rooms r
JOIN units u ON u.building_id = r.building_id AND u.unit_number = r.room_number
ON CONFLICT (room_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS charge_plans (
  plan_id        SERIAL PRIMARY KEY,
  building_id    INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  effective_from VARCHAR(6) NOT NULL,
  definition     JSONB NOT NULL,
  created_by     INT,
  created_at     TIMESTAMP NOT NULL DEFAULT now(),
  updated_at     TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_charge_plans_building_month UNIQUE (building_id, effective_from)
);

CREATE TABLE IF NOT EXISTS month_inputs (
  building_id  INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  charge_month VARCHAR(6) NOT NULL,
  inputs       JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at   TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (building_id, charge_month)
);

CREATE TABLE IF NOT EXISTS statements (
  statement_id    SERIAL PRIMARY KEY,
  building_id     INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  unit_id         INT REFERENCES units(unit_id) ON DELETE SET NULL,
  charge_month    VARCHAR(6) NOT NULL,
  unit_number     INT NOT NULL,
  unit_name       VARCHAR(255) NOT NULL DEFAULT '',
  area            NUMERIC(12,2) NOT NULL DEFAULT 0,
  usage           JSONB NOT NULL DEFAULT '{}'::jsonb,
  lines           JSONB NOT NULL DEFAULT '[]'::jsonb,
  group_totals    JSONB NOT NULL DEFAULT '[]'::jsonb,
  total           NUMERIC(14,2) NOT NULL DEFAULT 0,
  plan_snapshot   JSONB,
  inputs_snapshot JSONB,
  status          VARCHAR(16) NOT NULL DEFAULT 'issued',
  issued_at       TIMESTAMP NOT NULL DEFAULT now(),
  issued_by       INT,
  paid_amount     NUMERIC(14,2) NOT NULL DEFAULT 0,
  paid_at         DATE,
  memo            TEXT,
  created_at      TIMESTAMP NOT NULL DEFAULT now(),
  updated_at      TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_statements_building_month_unit UNIQUE (building_id, charge_month, unit_number)
);
CREATE INDEX IF NOT EXISTS idx_statements_month ON statements(building_id, charge_month);

CREATE TABLE IF NOT EXISTS building_settings (
  building_id INT PRIMARY KEY REFERENCES buildings(building_id) ON DELETE CASCADE,
  statement   JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS building_members (
  building_id INT NOT NULL REFERENCES buildings(building_id) ON DELETE CASCADE,
  user_id     INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  role        VARCHAR(16) NOT NULL DEFAULT 'owner',
  created_at  TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (building_id, user_id)
);
INSERT INTO building_members (building_id, user_id, role)
SELECT b.building_id, b.user_id, 'owner' FROM buildings b
WHERE b.user_id IS NOT NULL AND EXISTS (SELECT 1 FROM users u WHERE u.user_id = b.user_id)
ON CONFLICT DO NOTHING;
`;

/** 내 계정 — 비밀번호를 바꾼 시각(그 전에 받은 토큰은 받지 않는다). timestamptz: 서버·DB 시간대가 달라도 같은 순간. */
const m005 = `
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
`;

export const MIGRATIONS: SqlMigration[] = [
  { name: '001_additive', sql: m001 },
  { name: '002_calc_inputs', sql: m002 },
  { name: '003_meter_photos', sql: m003 },
  { name: '004_v2_core', sql: m004 },
  { name: '005_account', sql: m005 },
];
