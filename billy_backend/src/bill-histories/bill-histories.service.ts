import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BillHistory } from './bill-history.entity';
import { BillHistoryDto } from './dto/bill-history.dto';

@Injectable()
export class BillHistoriesService {
  constructor(@InjectRepository(BillHistory) private repo: Repository<BillHistory>) {}

  findAll() {
    return this.repo.find();
  }

  async findOne(id: number) {
    const bh = await this.repo.findOne({ where: { billHistoryId: id } });
    if (!bh) throw new NotFoundException('청구 내역을 찾을 수 없습니다');
    return bh;
  }

  findByChargeMonth(month: string, buildingId: number) {
    return this.repo.find({ where: { chargeMonth: month, buildingId } });
  }

  /**
   * 청구 내역 저장. (chargeMonth + roomNumber + buildingId) 가 같은 행이 있으면 갱신, 없으면 생성.
   * 레거시 Go 의 upsert 의도를 그대로 따르되, 갱신 시 PK 미설정 버그를 바로잡았다.
   */
  async upsertOne(dto: BillHistoryDto): Promise<BillHistory> {
    const existing = await this.repo.findOne({
      where: { chargeMonth: dto.chargeMonth, roomNumber: dto.roomNumber, buildingId: dto.buildingId },
    });
    if (existing) {
      await this.repo.update({ billHistoryId: existing.billHistoryId }, dto);
      return this.findOne(existing.billHistoryId);
    }
    return this.repo.save(this.repo.create(dto));
  }

  /** 단건 또는 배열 일괄 저장(계산 결과 저장용). */
  async create(payload: BillHistoryDto | BillHistoryDto[]) {
    const list = Array.isArray(payload) ? payload : [payload];
    const saved: BillHistory[] = [];
    for (const dto of list) saved.push(await this.upsertOne(dto));
    return Array.isArray(payload) ? saved : saved[0];
  }

  async update(id: number, dto: BillHistoryDto) {
    await this.findOne(id);
    await this.repo.update({ billHistoryId: id }, dto);
    return this.findOne(id);
  }

  async remove(id: number) {
    await this.repo.delete({ billHistoryId: id });
    return { message: '청구 내역이 삭제되었습니다' };
  }
}
