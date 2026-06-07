import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

@Entity('bills')
export class Bill {
  @PrimaryGeneratedColumn({ name: 'bill_id' })
  billId: number;

  @Column({ name: 'water_measure', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  waterMeasure: number;

  @Column({ name: 'water_usage', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  waterUsage: number;

  @Column({ name: 'water_bill', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  waterBill: number;

  @Column({ name: 'electricity_measure', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  electricityMeasure: number;

  @Column({ name: 'electricity_usage', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  electricityUsage: number;

  @Column({ name: 'electricity_bill', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  electricityBill: number;

  @Column({ name: 'room_id', type: 'int' })
  roomId: number;

  @Column({ name: 'floor_id', type: 'int' })
  floorId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  /** YYYYMM */
  @Column({ name: 'charge_month', length: 6, default: '' })
  chargeMonth: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
