import { CanActivate, ExecutionContext, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AccessService } from './access.service';
import { MigrationService } from '../database/migration.service';

/**
 * :buildingId 경로의 v2 라우트용 — 그 건물 권한이 있는지, v2 테이블이 준비됐는지 확인한다.
 * JwtAuthGuard 뒤에 둔다(req.user 필요).
 */
@Injectable()
export class BuildingAccessGuard implements CanActivate {
  constructor(
    private readonly access: AccessService,
    private readonly migrations: MigrationService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    if (!this.migrations.isReady()) {
      throw new ServiceUnavailableException('새 기능용 데이터베이스가 아직 준비되지 않았습니다. 잠시 뒤 다시 시도해주세요.');
    }
    const raw = req.params?.buildingId;
    if (raw !== undefined) await this.access.assertBuilding(req.user, Number(raw));
    return true;
  }
}
