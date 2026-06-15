import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Unique } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

const dec = (name: string) => ({
  name,
  type: 'decimal' as const,
  precision: 14,
  scale: 2,
  default: 0,
  transformer: DecimalTransformer,
});

/**
 * 관리비 계산 "고지서 합계 입력값"을 건물·월별로 저장.
 * (전체 전기요금/사용량, 수도요금/사용량, 상수도/하수도요금 + 고지서 사진)
 * 다시 그 달을 열면 입력값과 사진이 복원된다.
 */
@Entity('calc_inputs')
@Unique('uq_calc_inputs_building_month', ['buildingId', 'chargeMonth'])
export class CalcInput {
  @PrimaryGeneratedColumn({ name: 'calc_input_id' })
  calcInputId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  /** YYYYMM */
  @Column({ name: 'charge_month', length: 6, default: '' })
  chargeMonth: string;

  @Column(dec('electricity_total_cost')) electricityTotalCost: number;
  @Column(dec('electricity_total_usage')) electricityTotalUsage: number;
  @Column(dec('water_total_cost')) waterTotalCost: number;
  @Column(dec('water_total_usage')) waterTotalUsage: number;
  @Column(dec('water_supply_cost')) waterSupplyCost: number;
  @Column(dec('water_sewer_cost')) waterSewerCost: number;

  /** 수도 고지서 사진(base64). */
  @Column({ name: 'water_photo', type: 'text', nullable: true })
  waterPhoto: string | null;

  /** 전기 고지서 사진들(base64 문자열 JSON 배열). */
  @Column({ name: 'elec_photos', type: 'text', nullable: true })
  elecPhotos: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
