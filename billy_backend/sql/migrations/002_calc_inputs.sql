-- 관리비 계산 "고지서 합계 입력값" + 고지서 사진을 건물·월별로 저장.
-- 다시 그 달을 열면 입력값/사진이 복원된다. (추가형 — 기존 데이터 영향 없음)

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
