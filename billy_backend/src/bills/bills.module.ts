import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Bill } from './bill.entity';
import { BillsService } from './bills.service';
import { ExcelService } from './excel.service';
import { MeterOcrService } from './meter-ocr.service';
import { BillsController } from './bills.controller';
import { RoomsModule } from '../rooms/rooms.module';
import { BuildingFeesModule } from '../building-fees/building-fees.module';
import { CalcInputsModule } from '../calc-inputs/calc-inputs.module';

@Module({
  imports: [TypeOrmModule.forFeature([Bill]), RoomsModule, BuildingFeesModule, CalcInputsModule],
  providers: [BillsService, ExcelService, MeterOcrService],
  controllers: [BillsController],
  exports: [BillsService, TypeOrmModule],
})
export class BillsModule {}
