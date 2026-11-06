import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { BuildingFeesService } from './building-fees.service';
import { UpsertBuildingFeeDto } from './dto/upsert-building-fee.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../access/admin.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('building-fees')
export class BuildingFeesController {
  constructor(
    private readonly service: BuildingFeesService,
    private readonly access: AccessService,
  ) {}

  @UseGuards(AdminGuard)
  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('buildings/:buildingId')
  async findByBuildingId(@Param('buildingId', ParseIntPipe) buildingId: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, buildingId);
    return this.service.findByBuildingId(buildingId);
  }

  @Post()
  async create(@Body() dto: UpsertBuildingFeeDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    return this.service.upsert(dto);
  }

  @Put()
  async update(@Body() dto: UpsertBuildingFeeDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    return this.service.upsert(dto);
  }

  @Delete('buildings/:buildingId')
  async remove(@Param('buildingId', ParseIntPipe) buildingId: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, buildingId);
    return this.service.remove(buildingId);
  }
}
