import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { RoomsService } from './rooms.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../access/admin.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('rooms')
export class RoomsController {
  constructor(
    private readonly roomsService: RoomsService,
    private readonly access: AccessService,
  ) {}

  @UseGuards(AdminGuard)
  @Get()
  findAll() {
    return this.roomsService.findAll();
  }

  @Get('buildings/:buildingId')
  async findByBuildingId(@Param('buildingId', ParseIntPipe) buildingId: number, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, buildingId);
    return this.roomsService.findByBuildingId(buildingId);
  }

  @Get('floors/:floorId')
  async findByFloorId(@Param('floorId', ParseIntPipe) floorId: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'floors', 'floor_id', floorId);
    return this.roomsService.findByFloorId(floorId);
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'rooms', 'room_id', id);
    return this.roomsService.findOne(id);
  }

  @Post()
  async create(@Body() dto: CreateRoomDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    await this.access.assertRow(user, 'floors', 'floor_id', dto.floorId);
    return this.roomsService.create(dto);
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateRoomDto, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'rooms', 'room_id', id);
    if (dto.buildingId !== undefined) await this.access.assertBuilding(user, dto.buildingId);
    if (dto.floorId !== undefined) await this.access.assertRow(user, 'floors', 'floor_id', dto.floorId);
    return this.roomsService.update(id, dto);
  }

  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'rooms', 'room_id', id);
    return this.roomsService.remove(id);
  }
}
