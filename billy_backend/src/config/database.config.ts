import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { User } from '../users/user.entity';
import { Building } from '../buildings/building.entity';
import { Floor } from '../floors/floor.entity';
import { Room } from '../rooms/room.entity';
import { Bill } from '../bills/bill.entity';
import { BillHistory } from '../bill-histories/bill-history.entity';
import { BuildingFee } from '../building-fees/building-fee.entity';
import { CalcInput } from '../calc-inputs/calc-input.entity';

const ALL_ENTITIES = [User, Building, Floor, Room, Bill, BillHistory, BuildingFee, CalcInput];

/**
 * PostgreSQL 연결. 스키마는 sql/schema.sql + sql/migrations 로 관리한다.
 * synchronize 는 기본 false (DB_SYNCHRONIZE=true 로만 켬 — 신규 환경 부트스트랩 용).
 */
export const databaseConfigFactory = (configService: ConfigService): TypeOrmModuleOptions => {
  const databaseUrl = process.env.DATABASE_URL;
  const synchronize = configService.get<string>('DB_SYNCHRONIZE') === 'true';

  const base = {
    type: 'postgres' as const,
    entities: ALL_ENTITIES,
    synchronize,
    extra: { max: 10, idleTimeoutMillis: 30000 },
  };

  if (databaseUrl) {
    // Railway 등 매니지드 Postgres
    return { ...base, url: databaseUrl, ssl: { rejectUnauthorized: false } };
  }
  return {
    ...base,
    host: configService.get<string>('DB_HOST', 'localhost'),
    port: configService.get<number>('DB_PORT', 5432),
    username: configService.get<string>('DB_USERNAME', 'postgres'),
    password: configService.get<string>('DB_PASSWORD', ''),
    database: configService.get<string>('DB_DATABASE', 'billy'),
  };
};
