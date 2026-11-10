import { BadRequestException, Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { StatementSettings } from './entities/building-setting.entity';
import { PlansService } from './plans.service';

/**
 * 기존 명세서(excel/bill.xlsx)에 박혀 있던 문구 — 기존 건물은 이 값으로 시작해 명세서가 예전과 똑같이 나온다.
 * 이제 설정에서 고친다(관리소 표기·납부 장소·공지·검침일·연체율).
 */
export const LEGACY_STATEMENT_SETTINGS: Required<Omit<StatementSettings, 'bankAccount' | 'dueDay'>> & Pick<StatementSettings, 'bankAccount' | 'dueDay'> = {
  managerTitle: '새아병원 관리사무소장',
  payPlace: '반여2동 우체국',
  notice:
    '☞ 입점주 여러분의 무궁한 발전을 진심으로 기원합니다.\n' +
    '☞ 당월 납부하는 대당 60,000원의 주차비는 (lMonth)/(fDate)-(lMonth)/(lDate) 까지 주차장 사용에 대한 요금으로 관리비 납부 시 함께 납부해 주시기 바랍니다.',
  meterDay: 15,
  lateFeeRate: 0.02,
  truncateUnit: 10,
  bankAccount: '',
  dueDay: undefined, // 비우면 고지월 말일
};

const GENERIC_STATEMENT_SETTINGS: StatementSettings = {
  managerTitle: '관리사무소',
  payPlace: '',
  notice: '',
  meterDay: 15,
  lateFeeRate: 0,
  truncateUnit: 1,
  bankAccount: '',
};

@Injectable()
export class SettingsService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly plans: PlansService,
  ) {}

  async get(buildingId: number): Promise<StatementSettings> {
    const rows = await this.dataSource.query('SELECT statement FROM building_settings WHERE building_id = $1', [buildingId]);
    const base = (await this.plans.defaultPresetId(buildingId)) === 'legacy-v1' ? LEGACY_STATEMENT_SETTINGS : GENERIC_STATEMENT_SETTINGS;
    return { ...base, ...(rows[0]?.statement ?? {}) };
  }

  async put(buildingId: number, dto: StatementSettings): Promise<StatementSettings> {
    const clean: StatementSettings = {};
    const text = (v: unknown, max: number) => String(v ?? '').slice(0, max);
    if (dto.managerTitle !== undefined) clean.managerTitle = text(dto.managerTitle, 60);
    if (dto.payPlace !== undefined) clean.payPlace = text(dto.payPlace, 80);
    if (dto.bankAccount !== undefined) clean.bankAccount = text(dto.bankAccount, 80);
    if (dto.notice !== undefined) clean.notice = text(dto.notice, 1000);
    const int = (v: unknown, lo: number, hi: number, name: string) => {
      const n = Number(v);
      if (!Number.isInteger(n) || n < lo || n > hi) throw new BadRequestException(`${name}은(는) ${lo}~${hi} 사이 숫자여야 합니다`);
      return n;
    };
    if (dto.meterDay !== undefined) clean.meterDay = int(dto.meterDay, 1, 31, '검침일');
    if (dto.dueDay !== undefined && dto.dueDay !== null) clean.dueDay = int(dto.dueDay, 1, 31, '납기일');
    // null = 납기일을 비운다(고지월 말일) — 합치기(||)로는 키가 안 지워져 따로 뺀다
    const clearDueDay = dto.dueDay === null;
    if (dto.lateFeeRate !== undefined) {
      const r = Number(dto.lateFeeRate);
      if (!Number.isFinite(r) || r < 0 || r > 0.1) throw new BadRequestException('연체율은 0~10% 사이여야 합니다');
      clean.lateFeeRate = r;
    }
    if (dto.truncateUnit !== undefined) {
      const t = Number(dto.truncateUnit);
      if (![1, 10, 100].includes(t)) throw new BadRequestException('절삭 단위는 1·10·100원 중 하나입니다');
      clean.truncateUnit = t;
    }
    await this.dataSource.query(
      `INSERT INTO building_settings (building_id, statement) VALUES ($1, $2)
       ON CONFLICT (building_id) DO UPDATE SET statement = building_settings.statement || EXCLUDED.statement, updated_at = now()`,
      [buildingId, JSON.stringify(clean)],
    );
    if (clearDueDay) {
      await this.dataSource.query(`UPDATE building_settings SET statement = statement - 'dueDay' WHERE building_id = $1`, [buildingId]);
    }
    return this.get(buildingId);
  }
}
