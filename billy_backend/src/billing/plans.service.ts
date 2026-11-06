import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, LessThanOrEqual, Repository } from 'typeorm';
import { ChargePlan } from './entities/charge-plan.entity';
import { ChargePlanDef } from './engine/types';
import { PlanError, validatePlan } from './engine/engine';
import { basicV1Plan, legacyV1Plan, presetPlan } from './presets';

export interface EffectivePlan {
  definition: ChargePlanDef;
  /** 저장된 버전의 적용 시작월(기본 요금표면 null). */
  effectiveFrom: string | null;
  source: 'saved' | 'default';
}

const MONTH_RE = /^\d{6}$/;

/**
 * 요금표 — 건물별, 적용 시작월이 있는 버전. 그달 이전의 가장 늦은 버전이 쓰인다.
 * 저장된 게 없으면 기존 건물은 '기존 방식'(building_fees 금액), 새 건물은 '기본 상가형'.
 */
@Injectable()
export class PlansService {
  constructor(
    @InjectRepository(ChargePlan) private readonly repo: Repository<ChargePlan>,
    private readonly dataSource: DataSource,
  ) {}

  async effective(buildingId: number, month: string): Promise<EffectivePlan> {
    const saved = await this.repo.findOne({
      where: { buildingId, effectiveFrom: LessThanOrEqual(month) },
      order: { effectiveFrom: 'DESC' },
    });
    if (saved) return { definition: saved.definition, effectiveFrom: saved.effectiveFrom, source: 'saved' };
    return { definition: await this.defaultPlan(buildingId), effectiveFrom: null, source: 'default' };
  }

  /** 기존 건물(고정 관리비나 청구가 있음) = 기존 방식, 새 건물 = 기본 상가형. */
  async defaultPlan(buildingId: number): Promise<ChargePlanDef> {
    return presetPlan(await this.defaultPresetId(buildingId), await this.legacyFees(buildingId));
  }

  async defaultPresetId(buildingId: number): Promise<string> {
    const fee = await this.dataSource.query('SELECT 1 FROM building_fees WHERE building_id = $1', [buildingId]);
    if (fee.length) return 'legacy-v1';
    const bills = await this.dataSource.query('SELECT 1 FROM bills WHERE building_id = $1 LIMIT 1', [buildingId]);
    return bills.length ? 'legacy-v1' : 'basic-v1';
  }

  /** 프리셋으로 시작하는 요금표(기존 방식이면 이 건물의 관리비 금액을 채운다). */
  async fromPreset(buildingId: number, presetId: string): Promise<ChargePlanDef> {
    if (presetId === 'legacy-v1') return legacyV1Plan(await this.legacyFees(buildingId));
    if (presetId === 'basic-v1') return basicV1Plan();
    return presetPlan(presetId);
  }

  private async legacyFees(buildingId: number) {
    const rows = await this.dataSource.query('SELECT * FROM building_fees WHERE building_id = $1', [buildingId]);
    if (!rows.length) return undefined;
    const f = rows[0];
    const n = (v: unknown) => parseFloat(String(v ?? 0)) || 0;
    return {
      generalManagementFee: n(f.general_management_fee),
      publicInspectionFee: n(f.public_inspection_fee),
      fireManagementFee: n(f.fire_management_fee),
      elevatorMaintenanceFee: n(f.elevator_maintenance_fee),
      septicTankManagementFee: n(f.septic_tank_management_fee),
      electricalManagementFee: n(f.electrical_management_fee),
      parkingManagementFee: n(f.parking_management_fee),
    };
  }

  async save(buildingId: number, effectiveFrom: string, definition: ChargePlanDef, userId: number): Promise<EffectivePlan> {
    if (!MONTH_RE.test(effectiveFrom ?? '')) throw new BadRequestException('적용 시작월은 YYYYMM 형식이어야 합니다');
    const def = sanitizePlan(definition);
    try {
      validatePlan(def);
    } catch (e) {
      if (e instanceof PlanError) throw new BadRequestException(e.message);
      throw e;
    }
    await this.dataSource.query(
      `INSERT INTO charge_plans (building_id, effective_from, definition, created_by)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (building_id, effective_from) DO UPDATE SET definition = EXCLUDED.definition, created_by = EXCLUDED.created_by, updated_at = now()`,
      [buildingId, effectiveFrom, JSON.stringify(def), userId],
    );
    return { definition: def, effectiveFrom, source: 'saved' };
  }

  async versions(buildingId: number) {
    const rows = await this.repo.find({ where: { buildingId }, order: { effectiveFrom: 'DESC' } });
    return rows.map((r) => ({ effectiveFrom: r.effectiveFrom, preset: r.definition?.preset ?? null, items: r.definition?.items?.length ?? 0, updatedAt: r.updatedAt }));
  }
}

/** 화면에서 온 요금표를 저장 가능한 모양으로(알 수 없는 칸 제거·숫자 정리). */
export function sanitizePlan(input: ChargePlanDef): ChargePlanDef {
  if (!input || !Array.isArray(input.items) || !Array.isArray(input.groups)) throw new BadRequestException('요금표 형식이 올바르지 않습니다');
  if (input.items.length > 60) throw new BadRequestException('항목은 60개까지 만들 수 있습니다');
  const numOrUndef = (v: unknown) => (v === undefined || v === null || v === '' ? undefined : Number(v));
  return {
    preset: typeof input.preset === 'string' ? input.preset.slice(0, 32) : undefined,
    roundingMode: input.roundingMode === 'item' ? 'item' : 'end',
    billedUnits: input.billedUnits === 'all' ? 'all' : 'with_meters',
    groups: input.groups.slice(0, 12).map((g) => ({ code: String(g.code).slice(0, 40), label: String(g.label ?? '').slice(0, 40) })),
    items: input.items.map((i) => {
      const out: Record<string, unknown> = {
        code: String(i.code ?? '').slice(0, 40),
        label: String(i.label ?? '').slice(0, 60),
        group: String(i.group ?? ''),
        method: i.method,
      };
      if (i.utility) out.utility = i.utility === 'water' ? 'water' : 'electricity';
      if (i.cost) {
        out.cost = {
          ...(i.cost.input ? { input: String(i.cost.input).slice(0, 40) } : {}),
          ...(numOrUndef(i.cost.amount) !== undefined ? { amount: numOrUndef(i.cost.amount) } : {}),
          ...(i.cost.minusInputs?.length ? { minusInputs: i.cost.minusInputs.map((k) => String(k).slice(0, 40)) } : {}),
        };
      }
      if (i.usageInput) out.usageInput = String(i.usageInput).slice(0, 40);
      if (i.of) out.of = String(i.of).slice(0, 40);
      if (i.split) out.split = ['area', 'usage', 'equal'].includes(i.split) ? i.split : 'area';
      if (i.areaFormula) out.areaFormula = i.areaFormula === 'ratio' ? 'ratio' : 'mul_div';
      if (i.refs) out.refs = i.refs.map((r) => String(r).slice(0, 40));
      if (numOrUndef(i.rate) !== undefined) out.rate = numOrUndef(i.rate);
      if (numOrUndef(i.amount) !== undefined) out.amount = numOrUndef(i.amount);
      if (i.perUnit) out.perUnit = Object.fromEntries(Object.entries(i.perUnit).map(([k, v]) => [String(k), Number(v) || 0]));
      if (i.attr) out.attr = 'baseCost';
      if (i.directKey) out.directKey = String(i.directKey).slice(0, 40);
      if (i.scope) {
        out.scope = {
          ...(i.scope.only?.length ? { only: i.scope.only.map(Number).filter(Number.isFinite) } : {}),
          ...(i.scope.exclude?.length ? { exclude: i.scope.exclude.map(Number).filter(Number.isFinite) } : {}),
        };
      }
      if (i.category) out.category = String(i.category).slice(0, 40);
      if (i.hidden) out.hidden = true;
      return out as unknown as ChargePlanDef['items'][number];
    }),
  };
}
