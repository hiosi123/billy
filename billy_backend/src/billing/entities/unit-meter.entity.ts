import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

/** 계량기(rooms 행) → 호실 연결. 기존 rooms 테이블은 고치지 않는다. */
@Entity('unit_meters')
export class UnitMeter {
  @PrimaryColumn({ name: 'room_id', type: 'int' })
  roomId: number;

  @Column({ name: 'unit_id', type: 'int' })
  unitId: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
