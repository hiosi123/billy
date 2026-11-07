import { Global, Module } from '@nestjs/common';
import { AccessService } from './access.service';
import { BuildingAccessGuard } from './building-access.guard';
import { AdminGuard } from './admin.guard';

@Global()
@Module({
  providers: [AccessService, BuildingAccessGuard, AdminGuard],
  exports: [AccessService, BuildingAccessGuard, AdminGuard],
})
export class AccessModule {}
