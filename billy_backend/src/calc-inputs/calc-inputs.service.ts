import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CalcInput } from './calc-input.entity';
import { CalcInputDto } from './dto/calc-input.dto';

@Injectable()
export class CalcInputsService {
  constructor(@InjectRepository(CalcInput) private repo: Repository<CalcInput>) {}

  /** 엔티티의 elec_photos(JSON 문자열)를 배열로 풀어 응답. */
  private toResponse(e: CalcInput | null) {
    if (!e) return null;
    let elecPhotos: string[] = [];
    if (e.elecPhotos) {
      try {
        const parsed = JSON.parse(e.elecPhotos);
        if (Array.isArray(parsed)) elecPhotos = parsed;
      } catch {
        elecPhotos = [];
      }
    }
    return { ...e, elecPhotos };
  }

  async getByMonth(buildingId: number, chargeMonth: string) {
    const e = await this.repo.findOne({ where: { buildingId, chargeMonth } });
    return this.toResponse(e);
  }

  /** 건물·월 기준 upsert. 같은 (building, month) 행이 있으면 갱신. */
  async upsert(dto: CalcInputDto) {
    const data = {
      buildingId: dto.buildingId,
      chargeMonth: dto.chargeMonth,
      electricityTotalCost: dto.electricityTotalCost ?? 0,
      electricityTotalUsage: dto.electricityTotalUsage ?? 0,
      waterTotalCost: dto.waterTotalCost ?? 0,
      waterTotalUsage: dto.waterTotalUsage ?? 0,
      waterSupplyCost: dto.waterSupplyCost ?? 0,
      waterSewerCost: dto.waterSewerCost ?? 0,
      waterPhoto: dto.waterPhoto ?? null,
      elecPhotos: dto.elecPhotos && dto.elecPhotos.length ? JSON.stringify(dto.elecPhotos) : null,
    };
    const existing = await this.repo.findOne({
      where: { buildingId: dto.buildingId, chargeMonth: dto.chargeMonth },
    });
    if (existing) {
      await this.repo.update({ calcInputId: existing.calcInputId }, data);
    } else {
      await this.repo.save(this.repo.create(data));
    }
    return this.getByMonth(dto.buildingId, dto.chargeMonth);
  }
}
