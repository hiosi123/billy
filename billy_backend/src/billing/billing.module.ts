import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BillsModule } from '../bills/bills.module';
import { BillingController } from './billing.controller';
import { UnitsService } from './units.service';
import { PlansService } from './plans.service';
import { MonthsService } from './months.service';
import { SettingsService } from './settings.service';
import { StatementExcelService } from './statement-excel.service';
import { Unit } from './entities/unit.entity';
import { UnitMeter } from './entities/unit-meter.entity';
import { ChargePlan } from './entities/charge-plan.entity';
import { MonthInput } from './entities/month-input.entity';
import { Statement } from './entities/statement.entity';
import { BuildingSetting } from './entities/building-setting.entity';
import { BuildingMember } from './entities/building-member.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Unit, UnitMeter, ChargePlan, MonthInput, Statement, BuildingSetting, BuildingMember]), BillsModule],
  controllers: [BillingController],
  providers: [UnitsService, PlansService, MonthsService, SettingsService, StatementExcelService],
  exports: [UnitsService, PlansService, MonthsService],
})
export class BillingModule {}
