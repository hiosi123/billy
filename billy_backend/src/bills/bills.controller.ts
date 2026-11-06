import {
  BadRequestException,
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
import { AdminGuard } from '../access/admin.guard';
import { AccessService } from '../access/access.service';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('bills')
export class BillsController {
  constructor(
    private readonly billsService: BillsService,
    private readonly excelService: ExcelService,
    private readonly meterOcrService: MeterOcrService,
    private readonly access: AccessService,
  ) {}

  @UseGuards(AdminGuard)
  @Get()
  findAll() {
    return this.billsService.findAll();
  }

  // ── 정적 경로 (:id 보다 먼저) ──────────────────────────────
  @Get('conditions')
  async getByCondition(
    @CurrentUser() user: AuthUser,
    @Query('month') month = '',
    @Query('RoomId') roomId = '0',
    @Query('FloorId') floorId = '0',
    @Query('BuildingId') buildingId = '0',
  ) {
    // 건물을 정하지 않은 조회(여러 건물에 걸침)는 관리자만
    const bid = parseInt(buildingId, 10) || 0;
    if (bid) await this.access.assertBuilding(user, bid);
    else if (!this.access.isAdmin(user)) throw new BadRequestException('건물을 지정해주세요');
    return this.billsService.getByCondition(
      month,
      parseInt(roomId, 10) || 0,
      parseInt(floorId, 10) || 0,
      parseInt(buildingId, 10) || 0,
    );
  }

  @Post('measurements')
  async insertMeasure(@Body() usage: UsageDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, usage.BuildingId);
    await this.billsService.assertRoomInBuilding(usage.RoomId, usage.BuildingId);
    return this.billsService.insertMeasure(usage);
  }

  @Post('calculate')
  async calculate(@Body() req: CalculateBillDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, req.BuildingId);
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
  async readBillElec(@Body() dto: ReadBillElecDto, @CurrentUser() user: AuthUser) {
    // 같은 건물의 지난 고지서 사진을 예시로 넣으므로 남의 건물 번호는 막는다
    if (dto.buildingId) await this.access.assertBuilding(user, dto.buildingId);
    return this.meterOcrService.readBillElec(dto);
  }

  @Post('excel')
  async makeExcel(@Body() bills: ExcelBillDto[], @Res() res: Response, @CurrentUser() user: AuthUser) {
    if (!Array.isArray(bills) || bills.length === 0) throw new BadRequestException('생성할 청구 데이터가 없습니다');
    const ids = new Set(bills.map((b) => Number(b?.BuildingId)));
    if (ids.size !== 1) throw new BadRequestException('한 건물의 명세서만 만들 수 있습니다');
    await this.access.assertBuilding(user, [...ids][0]);
    const { buffer, filename } = await this.excelService.makeBillExcel(bills);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename=${filename}`,
    });
    res.send(buffer);
  }

  // ── 동적 경로 ───────────────────────────────────────────
  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bills', 'bill_id', id);
    return this.billsService.findOne(id);
  }

  @Post()
  async create(@Body() dto: CreateBillDto, @CurrentUser() user: AuthUser) {
    await this.access.assertBuilding(user, dto.buildingId);
    return this.billsService.create(dto);
  }

  @Put(':id')
  async update(@Param('id', ParseIntPipe) id: number, @Body() dto: CreateBillDto, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bills', 'bill_id', id);
    await this.access.assertBuilding(user, dto.buildingId);
    return this.billsService.update(id, dto);
  }

  @Delete(':id')
  async remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {
    await this.access.assertRow(user, 'bills', 'bill_id', id);
    return this.billsService.remove(id);
  }
}
