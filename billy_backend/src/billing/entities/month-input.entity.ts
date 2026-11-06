import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';

/** 기존 calc_inputs 6칸 밖의 월 입력값(요금표가 요구하는 고지서 금액·직접 입력 등). */
@Entity('month_inputs')
export class MonthInput {
  @PrimaryColumn({ name: 'building_id', type: 'int' })
  buildingId: number;

  @PrimaryColumn({ name: 'charge_month', length: 6 })
  chargeMonth: string;

  @Column({ name: 'inputs', type: 'jsonb', default: {} })
  inputs: Record<string, number>;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
