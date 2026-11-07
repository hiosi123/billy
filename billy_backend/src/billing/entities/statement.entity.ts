import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../../common/decimal.transformer';
import { ChargePlanDef, EngineGroupTotal, EngineLine } from '../engine/types';

/**
 * 확정 명세서 — 서버가 계산한 값을 그대로 저장한 스냅샷(그때의 호실 이름·요금표·입력값 포함).
 * 엑셀·이미지는 이것에서 만든다. 다시 확정하면 계산 칸만 바뀌고 입금 기록은 남는다.
 */
@Entity('statements')
export class Statement {
  @PrimaryGeneratedColumn({ name: 'statement_id' })
  statementId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @Column({ name: 'unit_id', type: 'int', nullable: true })
  unitId: number | null;

  @Column({ name: 'charge_month', length: 6 })
  chargeMonth: string;

  @Column({ name: 'unit_number', type: 'int' })
  unitNumber: number;

  @Column({ name: 'unit_name', length: 255, default: '' })
  unitName: string;

  @Column({ name: 'area', type: 'decimal', precision: 12, scale: 2, default: 0, transformer: DecimalTransformer })
  area: number;

  @Column({ name: 'usage', type: 'jsonb', default: {} })
  usage: Record<string, number>;

  @Column({ name: 'lines', type: 'jsonb', default: [] })
  lines: EngineLine[];

  @Column({ name: 'group_totals', type: 'jsonb', default: [] })
  groupTotals: EngineGroupTotal[];

  @Column({ name: 'total', type: 'decimal', precision: 14, scale: 2, default: 0, transformer: DecimalTransformer })
  total: number;

  @Column({ name: 'plan_snapshot', type: 'jsonb', nullable: true })
  planSnapshot: ChargePlanDef | null;

  @Column({ name: 'inputs_snapshot', type: 'jsonb', nullable: true })
  inputsSnapshot: Record<string, number> | null;

  @Column({ name: 'status', length: 16, default: 'issued' })
  status: string;

  @Column({ name: 'issued_at', type: 'timestamp' })
  issuedAt: Date;

  @Column({ name: 'issued_by', type: 'int', nullable: true })
  issuedBy: number | null;

  @Column({ name: 'paid_amount', type: 'decimal', precision: 14, scale: 2, default: 0, transformer: DecimalTransformer })
  paidAmount: number;

  @Column({ name: 'paid_at', type: 'date', nullable: true })
  paidAt: string | null;

  @Column({ name: 'memo', type: 'text', nullable: true })
  memo: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
