import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

@Entity('floors')
export class Floor {
  @PrimaryGeneratedColumn({ name: 'floor_id' })
  floorId: number;

  @Column({ name: 'floor', type: 'int' })
  floor: number;

  @Column({ name: 'floor_space', type: 'decimal', precision: 10, scale: 2, default: 0, transformer: DecimalTransformer })
  floorSpace: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
