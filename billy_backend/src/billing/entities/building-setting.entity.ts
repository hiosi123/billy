import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';

/** 명세서 설정(관리소 표기·납부 장소/계좌·공지·검침일·납기일·연체율·절삭 단위). */
export interface StatementSettings {
  managerTitle?: string;
  payPlace?: string;
  bankAccount?: string;
  notice?: string;
  meterDay?: number;
  dueDay?: number;
  lateFeeRate?: number;
  truncateUnit?: number;
}

@Entity('building_settings')
export class BuildingSetting {
  @PrimaryColumn({ name: 'building_id', type: 'int' })
  buildingId: number;

  @Column({ name: 'statement', type: 'jsonb', default: {} })
  statement: StatementSettings;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
