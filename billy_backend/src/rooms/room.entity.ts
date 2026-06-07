import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

@Entity('rooms')
export class Room {
  @PrimaryGeneratedColumn({ name: 'room_id' })
  roomId: number;

  @Column({ name: 'room_number', type: 'int' })
  roomNumber: number;

  @Column({ name: 'room_base_cost', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  roomBaseCost: number;

  @Column({ name: 'measure_machine', length: 64 })
  measureMachine: string;

  @Column({ name: 'room_name', length: 255 })
  roomName: string;

  @Column({ name: 'room_space', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  roomSpace: number;

  @Column({ name: 'strict_water', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  strictWater: number;

  @Column({ name: 'strict_electricity', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  strictElectricity: number;

  @Column({ name: 'measure_no', type: 'int', default: 0 })
  measureNo: number;

  @Column({ name: 'measure_multiply', type: 'decimal', precision: 10, scale: 2, default: 1, transformer: DecimalTransformer })
  measureMultiply: number;

  @Column({ name: 'floor_id', type: 'int' })
  floorId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  /** floors 조인으로 채워지는 표시용 값(컬럼 아님). */
  floor?: number;
}
