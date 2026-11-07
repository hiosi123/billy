import { Controller, Get } from '@nestjs/common';
import { MigrationService } from './migration.service';

/**
 * 배포 확인용(로그인 불필요). 어떤 커밋이 떠 있는지, 마이그레이션이 다 들어갔는지 본다.
 * RAILWAY_GIT_COMMIT_SHA 는 Railway 가 배포마다 넣어 준다.
 */
@Controller('health')
export class HealthController {
  constructor(private readonly migrations: MigrationService) {}

  @Get()
  health() {
    const m = this.migrations.getStatus();
    return {
      ok: m.failed === null,
      commit: (process.env.RAILWAY_GIT_COMMIT_SHA ?? 'local').slice(0, 7),
      v2: this.migrations.isReady(),
      migrations: m,
    };
  }
}
