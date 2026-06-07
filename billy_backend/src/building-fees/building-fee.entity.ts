import { Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';
import { DecimalTransformer } from '../common/decimal.transformer';

const dec = (name: string) => ({
  name,
  type: 'decimal' as const,
  precision: 10,
  scale: 2,
  default: 0,
  transformer: DecimalTransformer,
});

/**
 * 건물 고정 관리비. 기존 스키마상 building_id 가 PK(AUTO_INCREMENT)지만,
 * 의미상 건물당 1행이라 building_id 를 그대로 키로 사용한다.
 */
@Entity('building_fees')
export class BuildingFee {
  @PrimaryColumn({ name: 'building_id', type: 'int' })
  buildingId: number;

  @Column(dec('general_management_fee')) generalManagementFee: number;
  @Column(dec('public_inspection_fee')) publicInspectionFee: number;
  @Column(dec('fire_management_fee')) fireManagementFee: number;
  @Column(dec('elevator_maintenance_fee')) elevatorMaintenanceFee: number;
  @Column(dec('septic_tank_management_fee')) septicTankManagementFee: number;
  @Column(dec('electrical_management_fee')) electricalManagementFee: number;
  @Column(dec('parking_management_fee')) parkingManagementFee: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
