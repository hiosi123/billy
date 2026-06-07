import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Building } from './building.entity';
import { CreateBuildingDto } from './dto/create-building.dto';
import { UpdateBuildingDto } from './dto/update-building.dto';

@Injectable()
export class BuildingsService {
  constructor(@InjectRepository(Building) private buildingsRepo: Repository<Building>) {}

  findAll() {
    return this.buildingsRepo.find({ order: { buildingId: 'ASC' } });
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
    return this.buildingsRepo.save(building);
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
