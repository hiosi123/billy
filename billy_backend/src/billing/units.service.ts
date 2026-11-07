import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { EngineUnit } from './engine/types';

export interface UnitMeterView {
  roomId: number;
  label: string; // 계량기 명칭(천리안안과-1)
  measureMultiply: number;
  strictWater: number;
  strictElectricity: number;
}

export interface UnitView {
  unitId: number;
  unitNumber: number;
  name: string;
  area: number;
  baseCost: number;
  floorId: number | null;
  floor: number | null;
  meters: UnitMeterView[];
}

const num = (v: unknown) => (v === null || v === undefined ? 0 : parseFloat(String(v)) || 0);

/**
 * 호실(청구 단위). 계량기(rooms 행)와 분리해, 면적이 '그 호수의 첫 계량기 행'에 흔들리지 않게 한다.
 * 호실 순서는 대표 계량기 행(가장 작은 room_id) 순서 — 기존 계산의 호수 순서와 같다(합계 끝자리까지 같게).
 */
@Injectable()
export class UnitsService {
  constructor(private readonly dataSource: DataSource) {}

  /** 아직 호실에 이어지지 않은 계량기 행을 호수 기준으로 잇는다(없는 호실은 대표 행으로 만든다). 여러 번 불러도 같다. */
  async sync(buildingId: number): Promise<void> {
    await this.dataSource.query(
      `INSERT INTO units (building_id, floor_id, unit_number, name, area, base_cost, sort)
       SELECT r.building_id, (SELECT fl.floor_id FROM floors fl WHERE fl.floor_id = r.floor_id),
              r.room_number, COALESCE(r.room_name, ''), COALESCE(r.room_space, 0), COALESCE(r.room_base_cost, 0), r.room_number
       FROM rooms r
       JOIN (SELECT MIN(room_id) AS room_id FROM rooms
             WHERE building_id = $1 AND room_id NOT IN (SELECT room_id FROM unit_meters)
             GROUP BY room_number) f ON f.room_id = r.room_id
       ORDER BY r.room_id
       ON CONFLICT (building_id, unit_number) DO NOTHING`,
      [buildingId],
    );
    await this.dataSource.query(
      `INSERT INTO unit_meters (room_id, unit_id)
       SELECT r.room_id, u.unit_id FROM rooms r
       JOIN units u ON u.building_id = r.building_id AND u.unit_number = r.room_number
       WHERE r.building_id = $1
       ON CONFLICT (room_id) DO NOTHING`,
      [buildingId],
    );
  }

  async list(buildingId: number): Promise<UnitView[]> {
    await this.sync(buildingId);
    const units = await this.dataSource.query(
      `SELECT u.unit_id, u.unit_number, u.name, u.area, u.base_cost, u.floor_id, fl.floor,
              (SELECT MIN(um.room_id) FROM unit_meters um WHERE um.unit_id = u.unit_id) AS first_room
       FROM units u LEFT JOIN floors fl ON fl.floor_id = u.floor_id
       WHERE u.building_id = $1
       ORDER BY first_room NULLS LAST, u.unit_id`,
      [buildingId],
    );
    const meters = await this.dataSource.query(
      `SELECT r.room_id, r.measure_machine, r.room_name, r.measure_multiply, r.strict_water, r.strict_electricity, um.unit_id
       FROM rooms r JOIN unit_meters um ON um.room_id = r.room_id
       WHERE r.building_id = $1 ORDER BY r.room_id`,
      [buildingId],
    );
    return units.map((u: any) => ({
      unitId: Number(u.unit_id),
      unitNumber: Number(u.unit_number),
      name: u.name,
      area: num(u.area),
      baseCost: num(u.base_cost),
      floorId: u.floor_id === null ? null : Number(u.floor_id),
      floor: u.floor === null || u.floor === undefined ? null : Number(u.floor),
      meters: meters
        .filter((m: any) => Number(m.unit_id) === Number(u.unit_id))
        .map((m: any) => ({
          roomId: Number(m.room_id),
          label: m.measure_machine || m.room_name || '',
          measureMultiply: num(m.measure_multiply) || 1,
          strictWater: num(m.strict_water),
          strictElectricity: num(m.strict_electricity),
        })),
    }));
  }

  async engineUnits(buildingId: number): Promise<EngineUnit[]> {
    return (await this.list(buildingId)).map((u) => ({
      unitId: u.unitId,
      unitNumber: u.unitNumber,
      name: u.name,
      area: u.area,
      baseCost: u.baseCost,
    }));
  }

  /** 호실 이름·면적·고정값 수정(계량기 행은 건드리지 않는다). */
  async update(buildingId: number, unitId: number, dto: { name?: string; area?: number; baseCost?: number }): Promise<UnitView> {
    const rows = await this.dataSource.query('SELECT unit_id FROM units WHERE unit_id = $1 AND building_id = $2', [unitId, buildingId]);
    if (rows.length === 0) throw new NotFoundException('호실을 찾을 수 없습니다');
    const sets: string[] = [];
    const params: unknown[] = [];
    const add = (col: string, v: unknown) => {
      params.push(v);
      sets.push(`${col} = $${params.length}`);
    };
    if (dto.name !== undefined) add('name', String(dto.name).slice(0, 255));
    if (dto.area !== undefined) {
      if (!Number.isFinite(dto.area) || dto.area < 0) throw new BadRequestException('면적은 0 이상의 숫자여야 합니다');
      add('area', dto.area);
    }
    if (dto.baseCost !== undefined) {
      if (!Number.isFinite(dto.baseCost) || dto.baseCost < 0) throw new BadRequestException('금액은 0 이상의 숫자여야 합니다');
      add('base_cost', dto.baseCost);
    }
    if (sets.length > 0) {
      params.push(unitId);
      await this.dataSource.query(`UPDATE units SET ${sets.join(', ')}, updated_at = now() WHERE unit_id = $${params.length}`, params);
    }
    return (await this.list(buildingId)).find((u) => u.unitId === unitId)!;
  }
}
