import { Body, Controller, Get, Param, ParseIntPipe, Post, UseGuards } from '@nestjs/common';
import { CalcInputsService } from './calc-inputs.service';
import { CalcInputDto } from './dto/calc-input.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('bills/calc-inputs')
export class CalcInputsController {
  constructor(
    private readonly service: CalcInputsService,
    private readonly access: AccessService,
  ) {}

  /** 건물·월 기준 저장된 계산 입력값 조회(없으면 null). */
  @Get('building/:buildingId/month/:month')
  async getByMonth(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, buildingId);
    return this.service.getByMonth(buildingId, month);
  }

  /** 계산 입력값 저장(건물·월 upsert). */
  @Post()
  async upsert(@Body() dto: CalcInputDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    return this.service.upsert(dto);
  }
}
