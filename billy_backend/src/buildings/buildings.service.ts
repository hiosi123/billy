import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Building } from './building.entity';
import { CreateBuildingDto } from './dto/create-building.dto';
import { UpdateBuildingDto } from './dto/update-building.dto';

@Injectable()
export class BuildingsService {
  constructor(@InjectRepository(Building) private buildingsRepo: Repository<Building>) {}

  /** ids 가 null 이면 전부(관리자), 아니면 그 건물들만. */
  findAll(ids: number[] | null = null) {
    if (ids !== null && ids.length === 0) return Promise.resolve([]);
    return this.buildingsRepo.find({ where: ids === null ? {} : { buildingId: In(ids) }, order: { buildingId: 'ASC' } });
  }

  async findOne(id: number) {
    const building = await this.buildingsRepo.findOne({ where: { buildingId: id } });
    if (!building) throw new NotFoundException('건물을 찾을 수 없습니다');
    return building;
  }

  /** 현재 로그인 유저가 소유한 건물 목록. */
  findByUserId(userId: number) {
    return this.buildingsRepo.find({ where: { userId }, order: { buildingId: 'ASC' } });
  }

  async create(dto: CreateBuildingDto, userId: number) {
    const building = this.buildingsRepo.create({
      buildingName: dto.buildingName,
      buildingAddress: dto.buildingAddress,
      buildingFloors: dto.buildingFloors ?? 1,
      elevator: dto.elevator ?? 0,
      owner: dto.owner,
      userId,
    });
    const saved = await this.buildingsRepo.save(building);
    try {
      await this.buildingsRepo.query(
        `INSERT INTO building_members (building_id, user_id, role) VALUES ($1, $2, 'owner') ON CONFLICT DO NOTHING`,
        [saved.buildingId, userId],
      );
    } catch {
      // v2 테이블이 아직 없으면(마이그레이션 전) 소유자(user_id)만으로도 접근된다
    }
    return saved;
  }

  async update(id: number, dto: UpdateBuildingDto) {
    await this.findOne(id);
    await this.buildingsRepo.update({ buildingId: id }, dto);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.buildingsRepo.delete({ buildingId: id });
    return { message: '건물이 삭제되었습니다' };
  }
}
