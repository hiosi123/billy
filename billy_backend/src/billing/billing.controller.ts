import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Put, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BuildingAccessGuard } from '../access/building-access.guard';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { ChargePlanDef, METHOD_LABELS } from './engine/types';
import { INPUT_LABELS, LEGAL_CATEGORIES, PRESETS } from './presets';
import { PlansService, sanitizePlan } from './plans.service';
import { MonthsService } from './months.service';
import { UnitsService } from './units.service';
import { SettingsService } from './settings.service';
import { StatementExcelService } from './statement-excel.service';
import { StatementSettings } from './entities/building-setting.entity';

/**
 * v2 — 호실·요금표·월 마감·확정 명세서·명세서 설정.
 * :buildingId 가 있는 라우트는 BuildingAccessGuard 가 '내 건물'인지 확인한다.
 */
@UseGuards(JwtAuthGuard, BuildingAccessGuard)
@Controller()
export class BillingController {
  constructor(
    private readonly units: UnitsService,
    private readonly plans: PlansService,
    private readonly months: MonthsService,
    private readonly settings: SettingsService,
    private readonly statementExcel: StatementExcelService,
  ) {}

  /** 요금표 편집 화면에 필요한 고정 정보(프리셋·방식 이름·법정 분류·입력 이름). */
  @Get('billing/catalog')
  catalog() {
    return { presets: PRESETS, methods: METHOD_LABELS, categories: LEGAL_CATEGORIES, inputs: INPUT_LABELS };
  }

  // ── 호실 ──
  @Get('buildings/:buildingId/units')
  listUnits(@Param('buildingId', ParseIntPipe) buildingId: number) {
    return this.units.list(buildingId);
  }

  @Put('buildings/:buildingId/units/:unitId')
  updateUnit(
    @Param('buildingId', ParseIntPipe) buildingId: number,
    @Param('unitId', ParseIntPipe) unitId: number,
    @Body() dto: { name?: string; area?: number; baseCost?: number },
  ) {
    return this.units.update(buildingId, unitId, dto);
  }

  // ── 요금표 ──
  @Get('buildings/:buildingId/plan')
  async plan(@Param('buildingId', ParseIntPipe) buildingId: number, @Query('month') month: string) {
    const m = /^\d{6}$/.test(month ?? '') ? month : '999912';
    const eff = await this.plans.effective(buildingId, m);
    return { ...eff, versions: await this.plans.versions(buildingId), defaultPreset: await this.plans.defaultPresetId(buildingId) };
  }

  @Get('buildings/:buildingId/plan/preset/:presetId')
  fromPreset(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('presetId') presetId: string) {
    return this.plans.fromPreset(buildingId, presetId);
  }

  @Put('buildings/:buildingId/plan')
  savePlan(
    @Param('buildingId', ParseIntPipe) buildingId: number,
    @Body() body: { effectiveFrom: string; definition: ChargePlanDef },
    @CurrentUser() user: AuthUser,
  ) {
    return this.plans.save(buildingId, body?.effectiveFrom, body?.definition, user.id);
  }

  /** 저장 안 한 요금표로 그달을 미리 계산(쓰기 없음) — '지난달에 적용하면'. */
  @Post('buildings/:buildingId/plan/preview')
  previewPlan(@Param('buildingId', ParseIntPipe) buildingId: number, @Body() body: { month: string; definition: ChargePlanDef }) {
    return this.months.preview(buildingId, body?.month, { definition: sanitizePlan(body?.definition) });
  }

  // ── 월 마감 ──
  @Get('buildings/:buildingId/months')
  overview(@Param('buildingId', ParseIntPipe) buildingId: number, @Query('count') count?: string, @Query('until') until?: string) {
    return this.months.overview(buildingId, count ? parseInt(count, 10) || 6 : 6, until);
  }

  @Get('buildings/:buildingId/months/:month/inputs')
  inputs(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string) {
    return this.months.getInputs(buildingId, month);
  }

  @Put('buildings/:buildingId/months/:month/inputs')
  saveInputs(
    @Param('buildingId', ParseIntPipe) buildingId: number,
    @Param('month') month: string,
    @Body() body: { values: Record<string, unknown>; photos?: { water?: string | null; electricity?: string[] } },
  ) {
    return this.months.saveInputs(buildingId, month, body?.values ?? {}, body?.photos);
  }

  @Post('buildings/:buildingId/months/:month/preview')
  preview(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string, @Body() body: { inputs?: Record<string, number> }) {
    return this.months.preview(buildingId, month, { inputs: body?.inputs });
  }

  @Post('buildings/:buildingId/months/:month/issue')
  issue(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string, @CurrentUser() user: AuthUser) {
    return this.months.issue(buildingId, month, user.id);
  }

  @Get('buildings/:buildingId/months/:month/statements')
  statements(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string) {
    return this.months.statements(buildingId, month);
  }

  @Get('buildings/:buildingId/months/:month/statements.xlsx')
  async statementsXlsx(@Param('buildingId', ParseIntPipe) buildingId: number, @Param('month') month: string, @Res() res: Response) {
    const { buffer, filename } = await this.statementExcel.build(buildingId, month);
    res.set({
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename=${filename}`,
    });
    res.send(buffer);
  }

  @Patch('buildings/:buildingId/statements/:statementId')
  payment(
    @Param('buildingId', ParseIntPipe) buildingId: number,
    @Param('statementId', ParseIntPipe) statementId: number,
    @Body() dto: { paidAmount?: number; paidAt?: string | null; memo?: string | null },
  ) {
    return this.months.recordPayment(buildingId, statementId, dto ?? {});
  }

  // ── 명세서 설정 ──
  @Get('buildings/:buildingId/settings')
  getSettings(@Param('buildingId', ParseIntPipe) buildingId: number) {
    return this.settings.get(buildingId);
  }

  @Put('buildings/:buildingId/settings')
  putSettings(@Param('buildingId', ParseIntPipe) buildingId: number, @Body() dto: StatementSettings) {
    return this.settings.put(buildingId, dto ?? {});
  }
}
