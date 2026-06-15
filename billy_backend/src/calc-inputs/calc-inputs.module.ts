import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CalcInput } from './calc-input.entity';
import { CalcInputsService } from './calc-inputs.service';
import { CalcInputsController } from './calc-inputs.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CalcInput])],
  providers: [CalcInputsService],
  controllers: [CalcInputsController],
  exports: [CalcInputsService, TypeOrmModule],
})
export class CalcInputsModule {}
