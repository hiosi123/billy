import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { MIGRATIONS } from './migrations';

export interface MigrationStatus {
  applied: string[];
  failed: { name: string; error: string } | null;
  pending: string[];
}

/**
 * 서버가 켜질 때 마이그레이션을 순서대로 한 번씩 적용한다(각각 트랜잭션, 다른 인스턴스와 겹치지 않게 advisory lock).
 *
 * 실패해도 서버는 켠다 — 기존 화면은 새 테이블에 기대지 않으니 계속 돌고, 새 기능만 '준비 안 됨'으로 막힌다.
 * (부팅을 막으면 Railway 가 502 를 낸다 — 10/03 뛰딩 사고.) 실패는 /health 에 보인다.
 */
@Injectable()
export class MigrationService implements OnModuleInit {
  private readonly logger = new Logger('Migrations');
  private status: MigrationStatus = { applied: [], failed: null, pending: MIGRATIONS.map((m) => m.name) };

  constructor(private readonly dataSource: DataSource) {}

  getStatus(): MigrationStatus {
    return this.status;
  }

  /** v2 기능을 쓸 수 있는지(004 적용됨). */
  isReady(): boolean {
    return this.status.applied.includes('004_v2_core');
  }

  async onModuleInit(): Promise<void> {
    try {
      await this.run();
    } catch (e) {
      this.logger.error(`마이그레이션 확인 실패: ${(e as Error).message}`);
    }
  }

  async run(): Promise<MigrationStatus> {
    const runner = this.dataSource.createQueryRunner();
    await runner.connect();
    try {
      await runner.query(
        'CREATE TABLE IF NOT EXISTS schema_migrations (name VARCHAR(100) PRIMARY KEY, applied_at TIMESTAMP NOT NULL DEFAULT now())',
      );
      const applied = new Set<string>(
        (await runner.query('SELECT name FROM schema_migrations')).map((r: { name: string }) => r.name),
      );
      this.status = { applied: [...applied], failed: null, pending: [] };

      for (const m of MIGRATIONS) {
        if (applied.has(m.name)) continue;
        await runner.startTransaction();
        try {
          await runner.query('SELECT pg_advisory_xact_lock(4242001)');
          // 다른 인스턴스가 그새 적용했으면 건너뛴다
          const done = await runner.query('SELECT 1 FROM schema_migrations WHERE name = $1', [m.name]);
          if (done.length === 0) {
            await runner.query(m.sql);
            await runner.query('INSERT INTO schema_migrations (name) VALUES ($1)', [m.name]);
          }
          await runner.commitTransaction();
          this.status.applied.push(m.name);
          this.logger.log(`적용: ${m.name}`);
        } catch (e) {
          await runner.rollbackTransaction();
          const error = (e as Error).message;
          this.status.failed = { name: m.name, error };
          this.status.pending = MIGRATIONS.map((x) => x.name).filter((n) => !this.status.applied.includes(n));
          this.logger.error(`실패: ${m.name} — ${error} (이후 마이그레이션은 건너뜀)`);
          break;
        }
      }
      return this.status;
    } finally {
      await runner.release();
    }
  }
}
