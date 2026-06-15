import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { BillsService } from './bills.service';
import { ExcelService } from './excel.service';
import { MeterOcrService } from './meter-ocr.service';
import { CreateBillDto } from './dto/create-bill.dto';
import { UsageDto } from './dto/usage.dto';
import { CalculateBillDto } from './dto/calculate-bill.dto';
import { ExcelBillDto } from './dto/excel-bill.dto';
import { ReadMeterDto } from './dto/read-meter.dto';
import { ReadBillDto } from './dto/read-bill.dto';
import { ReadBillAutoDto } from './dto/read-bill-auto.dto';
import { ReadBillElecDto } from './dto/read-bill-elec.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('bills')
export class BillsController {
  constructor(
    private readonly billsService: BillsService,
    private readonly excelService: ExcelService,
    private readonly meterOcrService: MeterOcrService,
  ) {}

  @Get()
  findAll() {
    return this.billsService.findAll();
  }

  // ── 정적 경로 (:id 보다 먼저) ──────────────────────────────
  @Get('conditions')
  getByCondition(
    @Query('month') month = '',
    @Query('RoomId') roomId = '0',
    @Query('FloorId') floorId = '0',
    @Query('BuildingId') buildingId = '0',
  ) {
    return this.billsService.getByCondition(
      month,
      parseInt(roomId, 10) || 0,
      parseInt(floorId, 10) || 0,
      parseInt(buildingId, 10) || 0,
    );
  }

  @Post('measurements')
  insertMeasure(@Body() usage: UsageDto) {
    return this.billsService.insertMeasure(usage);
  }

  @Post('calculate')
  calculate(@Body() req: CalculateBillDto) {
    return this.billsService.calculate(req);
  }

  /** 계량기 사진 → AI OCR로 지침값 읽기. */
  @Post('read-meter')
  readMeter(@Body() dto: ReadMeterDto) {
    return this.meterOcrService.readMeter(dto);
  }

  /** 공공요금 고지서 사진 → AI OCR로 합계 항목 추출. */
  @Post('read-bill')
  readBill(@Body() dto: ReadBillDto) {
    return this.meterOcrService.readBill(dto);
  }

  /** 고지서 사진 → 수도/전기 자동 판별 + 항목 추출(여러 장 한번에 업로드용). */
  @Post('read-bill-auto')
  readBillAuto(@Body() dto: ReadBillAutoDto) {
    return this.meterOcrService.readBillAuto(dto);
  }

  /** 전기 고지서 여러 장(청구서+내역서) → 전기요금계 + 당월 사용량. */
  @Post('read-bill-elec')
  readBillElec(@Body() dto: ReadBillElecDto) {
    return this.meterOcrService.readBillElec(dto);
  }

  @Post('excel')
  async makeExcel(@Body() bills: ExcelBillDto[], @Res() res: Response) {
    const { buffer, filename } = await this.excelService.makeBillExcel(bills);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename=${filename}`,
    });
    res.send(buffer);
  }

  // ── 동적 경로 ───────────────────────────────────────────
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.billsService.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateBillDto) {
    return this.billsService.create(dto);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: CreateBillDto) {
    return this.billsService.update(id, dto);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.billsService.remove(id);
  }
}
