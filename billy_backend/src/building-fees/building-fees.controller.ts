import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { BuildingFeesService } from './building-fees.service';
import { UpsertBuildingFeeDto } from './dto/upsert-building-fee.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('building-fees')
export class BuildingFeesController {
  constructor(private readonly service: BuildingFeesService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('buildings/:buildingId')
  findByBuildingId(@Param('buildingId', ParseIntPipe) buildingId: number) {
    return this.service.findByBuildingId(buildingId);
  }

  @Post()
  create(@Body() dto: UpsertBuildingFeeDto) {
    return this.service.upsert(dto);
  }

  @Put()
  update(@Body() dto: UpsertBuildingFeeDto) {
    return this.service.upsert(dto);
  }

  @Delete('buildings/:buildingId')
  remove(@Param('buildingId', ParseIntPipe) buildingId: number) {
    return this.service.remove(buildingId);
  }
}
