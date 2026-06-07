import { Body, Controller, Delete, Get, Param, ParseIntPipe, Post, Put, UseGuards } from '@nestjs/common';
import { BillHistoriesService } from './bill-histories.service';
import { BillHistoryDto } from './dto/bill-history.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('bills/histories')
export class BillHistoriesController {
  constructor(private readonly service: BillHistoriesService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('month/:month/building/:buildingId')
  findByChargeMonth(
    @Param('month') month: string,
    @Param('buildingId', ParseIntPipe) buildingId: number,
  ) {
    return this.service.findByChargeMonth(month, buildingId);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: BillHistoryDto | BillHistoryDto[]) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: BillHistoryDto) {
    return this.service.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
