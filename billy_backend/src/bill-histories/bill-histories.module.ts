import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BillHistory } from './bill-history.entity';
import { BillHistoriesService } from './bill-histories.service';
import { BillHistoriesController } from './bill-histories.controller';

@Module({
  imports: [TypeOrmModule.forFeature([BillHistory])],
  providers: [BillHistoriesService],
  controllers: [BillHistoriesController],
  exports: [BillHistoriesService, TypeOrmModule],
})
export class BillHistoriesModule {}
