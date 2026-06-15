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

  /**
   * RAG용: 같은 건물의 "정답 예시"(전기요금계>0 + 전기 사진 보유)를 가장 최근 것으로 조회.
   * excludeMonth(현재 추출 중인 달)는 제외해 자기 자신을 예시로 쓰지 않는다.
   * 같은 한전 양식이라 직전 달 예시가 정답 위치를 그대로 알려준다.
   */
  async latestElecExample(buildingId: number, excludeMonth?: string) {
    const rows = await this.repo.find({ where: { buildingId }, order: { chargeMonth: 'DESC' } });
    for (const e of rows) {
      if (excludeMonth && e.chargeMonth === excludeMonth) continue;
      const cost = Number(e.electricityTotalCost);
      if (!(cost > 0) || !e.elecPhotos) continue;
      let photos: string[] = [];
      try {
        const parsed = JSON.parse(e.elecPhotos);
        if (Array.isArray(parsed)) photos = parsed.filter((s) => typeof s === 'string' && s);
      } catch {
        photos = [];
      }
      if (photos.length === 0) continue;
      return {
        chargeMonth: e.chargeMonth,
        electricityTotalCost: cost,
        electricityTotalUsage: Number(e.electricityTotalUsage) || 0,
        elecPhotos: photos,
      };
    }
    return null;
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
