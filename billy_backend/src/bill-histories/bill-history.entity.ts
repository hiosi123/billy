import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

const dec = (name: string) => ({
  name,
  type: 'decimal' as const,
  precision: 10,
  scale: 2,
  default: 0,
  transformer: DecimalTransformer,
});

@Entity('bill_histories')
export class BillHistory {
  @PrimaryGeneratedColumn({ name: 'bill_history_id' })
  billHistoryId: number;

  @Column({ name: 'room_number', type: 'int' })
  roomNumber: number;

  /** YYYYMM */
  @Column({ name: 'charge_month', length: 6, default: '' })
  chargeMonth: string;

  @Column(dec('electricity_cost')) electricityCost: number;
  @Column(dec('electricity_cost_common')) electricityCostCommon: number;
  @Column(dec('electricity_cost_tax')) electricityCostTax: number;
  @Column(dec('electricity_cost_fund')) electricityCostFund: number;
  @Column(dec('electricity_cost_total')) electricityCostTotal: number;

  @Column(dec('water_cost_supply')) waterCostSupply: number;
  @Column(dec('water_cost_sewer')) waterCostSewer: number;
  @Column(dec('water_cost_common')) waterCostCommon: number;
  @Column(dec('water_cost_total')) waterCostTotal: number;

  @Column(dec('total_cost')) totalCost: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
