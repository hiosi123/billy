import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { ChargePlanDef } from '../engine/types';

/** 요금표 버전 — effective_from(YYYYMM)부터 적용. 그달 이전 가장 늦은 버전이 쓰인다. */
@Entity('charge_plans')
export class ChargePlan {
  @PrimaryGeneratedColumn({ name: 'plan_id' })
  planId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @Column({ name: 'effective_from', length: 6 })
  effectiveFrom: string;

  @Column({ name: 'definition', type: 'jsonb' })
  definition: ChargePlanDef;

  @Column({ name: 'created_by', type: 'int', nullable: true })
  createdBy: number | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
