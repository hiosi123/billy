import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { BuildingsService } from './buildings.service';
import { CreateBuildingDto } from './dto/create-building.dto';
import { UpdateBuildingDto } from './dto/update-building.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser, AuthUser } from '../common/current-user.decorator';
import { AccessService } from '../access/access.service';

@UseGuards(JwtAuthGuard)
@Controller('buildings')
export class BuildingsController {
  constructor(
    private readonly buildingsService: BuildingsService,
    private readonly access: AccessService,
  ) {}

  /** 볼 수 있는 건물 전부(관리자는 모든 건물, 그 밖에는 내 건물·멤버인 건물). */
  @Get()
  async findAll(@CurrentUser() user: AuthUser) {
    const ids = await this.access.accessibleBuildingIds(user);
    return this.buildingsService.findAll(ids);
  }

  // 정적 경로(:id 보다 먼저 선언) — 현재 유저의 건물
  @Get('user')
  findMine(@CurrentUser() user: AuthUser) {
    return this.buildingsService.findByUserId(user.id);
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, id);
    return this.buildingsService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateBuildingDto, @CurrentUser() user: AuthUser) {
    return this.buildingsService.create(dto, user.id);
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateBuildingDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, id);
    return this.buildingsService.update(id, dto);
  }

  /** 건물 삭제는 관리자나 그 건물 주인만 — 같이 쓰는 매니저 계정이 건물을 통째로 지우지 못하게. */
  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuildingOwner(user, id);
    return this.buildingsService.remove(id);
  }
}
