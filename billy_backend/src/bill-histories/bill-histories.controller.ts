import { BadRequestException, Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { BillHistoriesService } from './bill-histories.service';
import { BillHistoryDto } from './dto/bill-history.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

/**
 * body 가 단건/배열 유니언이라 전역 ValidationPipe 가 검사를 건너뛰었다(점검: billHistoryId 를 넣으면 남의 행을 덮어씀).
 * 여기서 행마다 DTO 로 바꿔 검사하고, DTO 밖의 칸(billHistoryId 등)은 버린다.
 */
function toDtos(body: unknown): BillHistoryDto[] {
  const list = Array.isArray(body) ? body : [body];
  if (list.length === 0 || list.length > 500) throw new BadRequestException('저장할 내역이 없거나 너무 많습니다');
  return list.map((row) => {
    const dto = plainToInstance(BillHistoryDto, row ?? {}, { excludeExtraneousValues: false });
    const errors = validateSync(dto, { whitelist: true });
    if (errors.length) throw new BadRequestException(errors.map((e) => Object.values(e.constraints ?? {}).join(', ')).join(' / '));
    return dto;
  });
}

@UseGuards(JwtAuthGuard)
@Controller('bills/histories')
export class BillHistoriesController {
  constructor(
    private readonly service: BillHistoriesService,
    private readonly access: AccessService,
  ) {}

  /** 볼 수 있는 건물의 내역만(관리자는 전부). */
  @Get()
  async findAll(@CurrentUser() user: AuthUser) {
    const ids = await this.access.accessibleBuildingIds(user);
    const all = await this.service.findAll();
    return ids === null ? all : all.filter((h) => ids.includes(h.buildingId));
  }

  @Get('month/:month/building/:buildingId')
  async findByChargeMonth(
    @Param('month') month: string,
    @Param('buildingId', ParseIntPipe) buildingId: number,
    @CurrentUser() user: AuthUser,
  ) {
    await this.access.assertBuilding(user, buildingId);
    return this.service.findByChargeMonth(month, buildingId);
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bill_histories', 'bill_history_id', id);
    return this.service.findOne(id);
  }

  @Post()
  async create(@Body() body: unknown, @CurrentUser() user: AuthUser) {
    const dtos = toDtos(body);
    for (const id of new Set(dtos.map((d) => d.buildingId))) await this.access.assertBuilding(user, id);
    return this.service.create(Array.isArray(body) ? dtos : dtos[0]);
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() body: unknown, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bill_histories', 'bill_history_id', id);
    const [dto] = toDtos(body);
    await this.access.assertBuilding(user, dto.buildingId);
    return this.service.update(id, dto);
  }

  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bill_histories', 'bill_history_id', id);
    return this.service.remove(id);
  }
}
