import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BuildingFee } from './building-fee.entity';
import { UpsertBuildingFeeDto } from './dto/upsert-building-fee.dto';

@Injectable()
export class BuildingFeesService {
  constructor(@InjectRepository(BuildingFee) private feesRepo: Repository<BuildingFee>) {}

  findAll() {
    return this.feesRepo.find();
  }

  async findByBuildingId(buildingId: number) {
    const fee = await this.feesRepo.findOne({ where: { buildingId } });
    if (!fee) throw new NotFoundException('건물 관리비 정보를 찾을 수 없습니다');
    return fee;
  }

  /** 건물당 1행 — 있으면 수정, 없으면 생성. */
  async upsert(dto: UpsertBuildingFeeDto) {
    const existing = await this.feesRepo.findOne({ where: { buildingId: dto.buildingId } });
    if (existing) {
      await this.feesRepo.update({ buildingId: dto.buildingId }, dto);
    } else {
      await this.feesRepo.save(this.feesRepo.create(dto));
    }
    return this.findByBuildingId(dto.buildingId);
  }

  async remove(buildingId: number) {
    await this.feesRepo.delete({ buildingId });
    return { message: '건물 관리비 정보가 삭제되었습니다' };
  }
}
