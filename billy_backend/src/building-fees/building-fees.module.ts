import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BuildingFee } from './building-fee.entity';
import { BuildingFeesService } from './building-fees.service';
import { BuildingFeesController } from './building-fees.controller';

@Module({
  imports: [TypeOrmModule.forFeature([BuildingFee])],
  providers: [BuildingFeesService],
  controllers: [BuildingFeesController],
  exports: [BuildingFeesService, TypeOrmModule],
})
export class BuildingFeesModule {}
