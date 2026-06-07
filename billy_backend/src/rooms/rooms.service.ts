import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Room } from './room.entity';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';

@Injectable()
export class RoomsService {
  constructor(@InjectRepository(Room) private roomsRepo: Repository<Room>) {}

  findAll() {
    return this.roomsRepo.find();
  }

  async findOne(id: number) {
    const room = await this.roomsRepo.findOne({ where: { roomId: id } });
    if (!room) throw new NotFoundException('호실을 찾을 수 없습니다');
    return room;
  }

  /**
   * 건물의 모든 호실 + 층 정보(floors.floor 조인).
   * 계산 로직(CalculateBill/Excel)이 room.floor 를 쓰므로 조인해서 채운다.
   */
  async findByBuildingId(buildingId: number): Promise<Room[]> {
    const rows = await this.roomsRepo
      .createQueryBuilder('r')
      .leftJoin('floors', 'f', 'f.floor_id = r.floor_id')
      .where('r.building_id = :buildingId', { buildingId })
      .addSelect('f.floor', 'r_floor')
      .getRawAndEntities();

    return rows.entities.map((room, i) => {
      room.floor = rows.raw[i]?.r_floor ?? undefined;
      return room;
    });
  }

  findByFloorId(floorId: number) {
    return this.roomsRepo.find({ where: { floorId } });
  }

  create(dto: CreateRoomDto) {
    return this.roomsRepo.save(
      this.roomsRepo.create({
        roomNumber: dto.roomNumber,
        roomBaseCost: dto.roomBaseCost ?? 0,
        measureMachine: dto.measureMachine,
        roomName: dto.roomName,
        roomSpace: dto.roomSpace ?? 0,
        strictWater: dto.strictWater ?? 0,
        strictElectricity: dto.strictElectricity ?? 0,
        measureNo: dto.measureNo ?? 0,
        measureMultiply: dto.measureMultiply ?? 1,
        floorId: dto.floorId,
        buildingId: dto.buildingId,
      }),
    );
  }

  async update(id: number, dto: UpdateRoomDto) {
    await this.findOne(id);
    await this.roomsRepo.update({ roomId: id }, dto);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.roomsRepo.delete({ roomId: id });
    return { message: '호실이 삭제되었습니다' };
  }
}
