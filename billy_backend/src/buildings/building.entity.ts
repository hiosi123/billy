import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('buildings')
export class Building {
  @PrimaryGeneratedColumn({ name: 'building_id' })
  buildingId: number;

  @Column({ name: 'building_name', length: 255 })
  buildingName: string;

  @Column({ name: 'building_address', length: 255 })
  buildingAddress: string;

  @Column({ name: 'building_floors', type: 'int', default: 1 })
  buildingFloors: number;

  @Column({ name: 'elevator', type: 'int', default: 0 })
  elevator: number;

  @Column({ name: 'owner', length: 255 })
  owner: string;

  /** 건물 소유 유저. 기존 스키마에 존재(nullable). */
  @Column({ name: 'user_id', type: 'int', nullable: true })
  userId: number | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
