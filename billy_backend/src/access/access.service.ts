import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { AuthUser } from '../common/current-user.decorator';
import { MigrationService } from '../database/migration.service';

/**
 * 건물 접근 권한 — '내 건물만'.
 * 관리자(admin) 계정은 모든 건물, 그 밖에는 건물 소유자(buildings.user_id)이거나 building_members 에 있어야 한다.
 * (2026-11 점검: 모든 라우트가 로그인 여부만 봐서 남의 건물을 읽고 지울 수 있었다)
 */
@Injectable()
export class AccessService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly migrations: MigrationService,
  ) {}

  isAdmin(user: AuthUser | undefined): boolean {
    return user?.role === 'admin';
  }

  async assertBuilding(user: AuthUser | undefined, buildingId: number): Promise<void> {
    if (!user) throw new ForbiddenException('로그인이 필요합니다');
    if (!Number.isInteger(buildingId) || buildingId <= 0) throw new BadRequestException('건물 번호가 올바르지 않습니다');
    const exists = await this.dataSource.query('SELECT user_id FROM buildings WHERE building_id = $1', [buildingId]);
    if (exists.length === 0) throw new NotFoundException('건물을 찾을 수 없습니다');
    if (this.isAdmin(user)) return;
    if (Number(exists[0].user_id) === user.id) return;
    if (this.migrations.isReady()) {
      const m = await this.dataSource.query('SELECT 1 FROM building_members WHERE building_id = $1 AND user_id = $2', [buildingId, user.id]);
      if (m.length > 0) return;
    }
    throw new ForbiddenException('이 건물에 접근할 권한이 없습니다');
  }

  /** 이 사용자가 볼 수 있는 건물 id 목록(관리자는 null = 전부). */
  async accessibleBuildingIds(user: AuthUser | undefined): Promise<number[] | null> {
    if (this.isAdmin(user)) return null;
    if (!user) return [];
    const sql = this.migrations.isReady()
      ? `SELECT building_id FROM buildings WHERE user_id = $1
         UNION SELECT building_id FROM building_members WHERE user_id = $1`
      : 'SELECT building_id FROM buildings WHERE user_id = $1';
    return (await this.dataSource.query(sql, [user.id])).map((r: { building_id: number }) => Number(r.building_id));
  }

  /** 테이블 행 → 건물 확인(id 로만 오는 라우트: 호실·층·청구·내역 수정/삭제 등). */
  async assertRow(user: AuthUser | undefined, table: 'rooms' | 'floors' | 'bills' | 'bill_histories', idColumn: string, id: number): Promise<void> {
    const rows = await this.dataSource.query(`SELECT building_id FROM ${table} WHERE ${idColumn} = $1`, [id]);
    if (rows.length === 0) throw new NotFoundException('대상을 찾을 수 없습니다');
    await this.assertBuilding(user, Number(rows[0].building_id));
  }
}
