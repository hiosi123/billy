import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { FloorsService } from './floors.service';
import { CreateFloorDto } from './dto/create-floor.dto';
import { UpdateFloorDto } from './dto/update-floor.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../access/admin.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('floors')
export class FloorsController {
  constructor(
    private readonly floorsService: FloorsService,
    private readonly access: AccessService,
  ) {}

  @UseGuards(AdminGuard)
  @Get()
  findAll() {
    return this.floorsService.findAll();
  }

  @Get('buildings/:buildingId')
  async findByBuildingId(@Param('buildingId', ParseIntPipe) buildingId: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, buildingId);
    return this.floorsService.findByBuildingId(buildingId);
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'floors', 'floor_id', id);
    return this.floorsService.findOne(id);
  }

  @Post()
  async create(@Body() dto: CreateFloorDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    return this.floorsService.create(dto);
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateFloorDto, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'floors', 'floor_id', id);
    if ((dto as { buildingId?: number }).buildingId !== undefined) await this.access.assertBuilding(user, (dto as { buildingId: number }).buildingId);
    return this.floorsService.update(id, dto);
  }

  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'floors', 'floor_id', id);
    return this.floorsService.remove(id);
  }
}
