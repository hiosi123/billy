import { Global, Module } from '@nestjs/common';
import { MigrationService } from './migration.service';
import { HealthController } from './health.controller';

@Global()
@Module({
  providers: [MigrationService],
  controllers: [HealthController],
  exports: [MigrationService],
})
export class DatabaseModule {}
