import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../../common/decimal.transformer';

/** 호실 = 청구 단위(면적·기본료·이름). 계량기(rooms 행)는 unit_meters 로 이어진다. */
@Entity('units')
export class Unit {
  @PrimaryGeneratedColumn({ name: 'unit_id' })
  unitId: number;

  @Column({ name: 'building_id', type: 'int' })
  buildingId: number;

  @Column({ name: 'floor_id', type: 'int', nullable: true })
  floorId: number | null;

  @Column({ name: 'unit_number', type: 'int' })
  unitNumber: number;

  @Column({ name: 'name', length: 255, default: '' })
  name: string;

  @Column({ name: 'area', type: 'decimal', precision: 12, scale: 2, default: 0, transformer: DecimalTransformer })
  area: number;

  /** 호실 고정값(기존 room_base_cost — 화재보험료 등). */
  @Column({ name: 'base_cost', type: 'decimal', precision: 14, scale: 2, default: 0, transformer: DecimalTransformer })
  baseCost: number;

  @Column({ name: 'sort', type: 'int', default: 0 })
  sort: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
