import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Floor } from './floor.entity';
import { CreateFloorDto } from './dto/create-floor.dto';
import { UpdateFloorDto } from './dto/update-floor.dto';

@Injectable()
export class FloorsService {
  constructor(@InjectRepository(Floor) private floorsRepo: Repository<Floor>) {}

  findAll() {
    return this.floorsRepo.find();
  }

  async findOne(id: number) {
    const floor = await this.floorsRepo.findOne({ where: { floorId: id } });
    if (!floor) throw new NotFoundException('층을 찾을 수 없습니다');
    return floor;
  }

  findByBuildingId(buildingId: number) {
    return this.floorsRepo.find({ where: { buildingId }, order: { floor: 'ASC' } });
  }

  create(dto: CreateFloorDto) {
    return this.floorsRepo.save(
      this.floorsRepo.create({ floor: dto.floor, floorSpace: dto.floorSpace ?? 0, buildingId: dto.buildingId }),
    );
  }

  async update(id: number, dto: UpdateFloorDto) {
    await this.findOne(id);
    await this.floorsRepo.update({ floorId: id }, dto);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.floorsRepo.delete({ floorId: id });
    return { message: '층이 삭제되었습니다' };
  }
}
