import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { CalcInputsService } from './calc-inputs.service';
import { CalcInputDto } from './dto/calc-input.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('bills/calc-inputs')
export class CalcInputsController {
  constructor(private readonly service: CalcInputsService) {}

  /** 건물·월 기준 저장된 계산 입력값 조회(없으면 null). */
  @Get('building/:buildingId/month/:month')
  getByMonth(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string) {
    return this.service.getByMonth(buildingId, month);
  }

  /** 계산 입력값 저장(건물·월 upsert). */
  @Post()
  upsert(@Body() dto: CalcInputDto) {
    return this.service.upsert(dto);
  }
}
