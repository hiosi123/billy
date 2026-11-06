import { Column, CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

/** 건물 멤버 — 이 건물을 보고 관리할 수 있는 사용자(소유자·관리자·열람자). */
@Entity('building_members')
export class BuildingMember {
  @PrimaryColumn({ name: 'building_id', type: 'int' })
  buildingId: number;

  @PrimaryColumn({ name: 'user_id', type: 'int' })
  userId: number;

  @Column({ name: 'role', length: 16, default: 'owner' })
  role: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
