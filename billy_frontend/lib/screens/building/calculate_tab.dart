import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/calc_result.dart';
import '../../utils/format.dart';
import '../../utils/image_pick.dart';
import '../../widgets/common.dart';
import '../../services/file_saver.dart';
import 'month_selector.dart';

class CalculateTab extends StatefulWidget {
  const CalculateTab({super.key});

  @override
  State<CalculateTab> createState() => _CalculateTabState();
}

class _CalculateTabState extends State<CalculateTab> {
  final _elecCost = TextEditingController();
  final _elecUsage = TextEditingController();
  final _waterCost = TextEditingController();
  final _waterUsage = TextEditingController();
  final _waterSupply = TextEditingController();
  final _waterSewer = TextEditingController();

  List<CalcResult> _results = [];

  // 업로드한 고지서 사진 보존(화면 확인용). 전기는 보통 2장(청구서+내역서).
  ({String data, String media})? _waterPhoto;
  final List<({String data, String media})> _elecPhotos = [];

  @override
  void dispose() {
    for (final c in [_elecCost, _elecUsage, _waterCost, _waterUsage, _waterSupply, _waterSewer]) {
      c.dispose();
    }
    super.dispose();
  }

  // 콤마가 섞여 있어도 안전하게 숫자로 파싱.
  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  int _applyWater(Map r) {
    var n = 0;
    void fill(TextEditingController c, dynamic v) {
      if (v is num) {
        c.text = money(v);
        n++;
      }
    }

    fill(_waterUsage, r['waterTotalUsage']);
    fill(_waterSupply, r['waterSupplyCost']);
    fill(_waterSewer, r['waterSewerCost']);
    fill(_waterCost, r['waterTotalCost']);
    return n;
  }

  int _applyElec(Map r) {
    var n = 0;
    void fill(TextEditingController c, dynamic v) {
      if (v is num) {
        c.text = money(v);
        n++;
      }
    }

    fill(_elecCost, r['electricityTotalCost']);
    fill(_elecUsage, r['electricityTotalUsage']);
    return n;
  }

  /// 수도 고지서 1장 → AI OCR → 수도 항목 입력 + 사진 보존.
  Future<void> _readWaterBill() async {
    final picked = await pickImageBase64(context, maxWidth: 2400); // 고지서는 글자가 작아 고해상도
    if (picked == null || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final r = await api.readBill(image: picked.data, type: 'water', mediaType: picked.media);
      if (!mounted) return;
      final filled = _applyWater(r);
      setState(() => _waterPhoto = picked);
      showSnack(context, filled > 0 ? '수도 고지서에서 $filled개 항목 입력 (사진과 비교해 확인)' : '수도 고지서에서 값을 인식하지 못했습니다',
          error: filled == 0);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 전기 고지서 여러 장(보통 청구서+내역서 2장) → 전기요금계 + 당월 사용량 종합 추출 + 사진 2장 보존.
  Future<void> _readElecBills() async {
    final images = await pickImagesBase64(maxWidth: 2400);
    if (images.isEmpty || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final r = await api.readBillElec(images: images.map((e) => e.data).toList(), mediaType: images.first.media);
      if (!mounted) return;
      final filled = _applyElec(r);
      setState(() => _elecPhotos
        ..clear()
        ..addAll(images));
      showSnack(context, filled > 0 ? '전기 고지서 ${images.length}장에서 $filled개 항목 입력 (사진과 비교해 확인)' : '전기 고지서에서 값을 인식하지 못했습니다',
          error: filled == 0);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 수도·전기 구분 없이 여러 장을 한 번에 업로드 → AI가 종류 자동 판별.
  /// 전기로 분류된 사진들은 함께 보고 전기요금계+당월사용량을 종합 추출한다.
  Future<void> _readBillsAuto() async {
    final images = await pickImagesBase64(maxWidth: 2400);
    if (images.isEmpty || !mounted) return;
    final api = context.read<AppProvider>().api;
    final elecImgs = <({String data, String media})>[];
    var water = 0, unknown = 0;
    for (final img in images) {
      try {
        final r = await api.readBillAuto(image: img.data, mediaType: img.media);
        final type = r['type'];
        if (type == 'water') {
          _applyWater(r);
          _waterPhoto = img;
          water++;
        } else if (type == 'electricity') {
          elecImgs.add(img); // 전기는 모아서 합산 추출
        } else {
          unknown++;
        }
      } catch (_) {
        unknown++;
      }
    }
    var elecFilled = 0;
    if (elecImgs.isNotEmpty) {
      try {
        final er = await api.readBillElec(images: elecImgs.map((e) => e.data).toList(), mediaType: elecImgs.first.media);
        elecFilled = _applyElec(er);
        _elecPhotos
          ..clear()
          ..addAll(elecImgs);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    final ok = water + (elecImgs.isNotEmpty ? 1 : 0);
    showSnack(
      context,
      ok > 0
          ? '수도 $water · 전기 ${elecImgs.length}장($elecFilled항목) 인식${unknown > 0 ? ' · 분류실패 $unknown' : ''} (확인 후 계산)'
          : '고지서 종류를 인식하지 못했습니다. 개별 버튼으로 다시 시도해주세요',
      error: ok == 0,
    );
  }

  Future<void> _calculate() async {
    final p = context.read<AppProvider>();
    final req = {
      'BuildingId': p.selectedBuilding!.buildingId,
      'Month': p.chargeMonth,
      'ElectricityTotalCost': _n(_elecCost),
      'ElectricityTotalUsage': _n(_elecUsage),
      'WaterTotalCost': _n(_waterCost),
      'WaterTotalUsage': _n(_waterUsage),
      'WaterSupplyCost': _n(_waterSupply),
      'WaterSewerCost': _n(_waterSewer),
    };
    if ((req['ElectricityTotalUsage'] as double) <= 0) {
      showSnack(context, '전체 전기 사용량을 입력해주세요', error: true);
      return;
    }
    try {
      final res = await p.api.calculateBill(req);
      setState(() => _results = res);
      if (mounted) showSnack(context, '${res.length}개 호실 계산 완료');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _downloadExcel() async {
    final p = context.read<AppProvider>();
    if (_results.isEmpty) {
      showSnack(context, '먼저 계산을 실행해주세요', error: true);
      return;
    }
    try {
      final bytes = await p.api.makeBillExcel(
          _results.map((e) => {...e.toExcelJson(), 'ChargeMonth': p.chargeMonth}).toList());
      final name = await saveXlsx(bytes, 'bills_${p.chargeMonth}.xlsx');
      if (mounted) showSnack(context, '엑셀 명세서 생성 완료 ($name)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _saveHistory() async {
    final p = context.read<AppProvider>();
    if (_results.isEmpty) return;
    try {
      final payload = _results
          .map((r) => {
                'roomNumber': r.roomNumber,
                'chargeMonth': p.chargeMonth,
                'electricityCost': r.electricityCost,
                'electricityCostCommon': r.electricityCostCommon,
                'electricityCostTax': r.electricityCostTax,
                'electricityCostFund': r.electricityCostFund,
                'electricityCostTotal': r.electricityCostTotal,
                'waterCostSupply': r.waterCostSupply,
                'waterCostSewer': r.waterCostSewer,
                'waterCostCommon': r.waterCostCommon,
                'waterCostTotal': r.waterCostTotal,
                'totalCost': r.totalCost,
                'buildingId': r.buildingId,
              })
          .toList();
      await p.api.saveBillHistories(payload);
      if (mounted) showSnack(context, '관리비 내역이 저장되었습니다 (관리비 내역 탭에서 확인)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalSum = _results.fold<double>(0, (s, r) => s + r.totalCost);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        MonthSelector(month: p.chargeMonth, onChanged: (m) => p.setChargeMonth(m)),
        const SizedBox(height: 14),
        SectionCard(
          title: '고지서 합계 입력',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              // 고지서 사진으로 AI 자동 입력
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BillyColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: BillyColors.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('고지서를 올리면 AI가 종류를 판별해 합계를 자동 입력합니다',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BillyColors.primaryDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: AsyncButton(
                        label: '고지서 여러 장 한번에 (자동 분류)',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _readBillsAuto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('또는 종류별로', style: TextStyle(fontSize: 11, color: BillyColors.textHint)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '수도 고지서',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.water,
                              onPressed: _readWaterBill,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '전기 고지서 (2장)',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.electricity,
                              onPressed: _readElecBills,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_waterPhoto != null || _elecPhotos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_waterPhoto != null) _billThumb(context, '수도 고지서', _waterPhoto!, BillyColors.water),
                          for (var i = 0; i < _elecPhotos.length; i++)
                            _billThumb(context, '전기 고지서 ${i + 1}', _elecPhotos[i], BillyColors.electricity),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _field2(
                _LabeledField(label: '전체 전기요금', controller: _elecCost, color: BillyColors.electricity, suffix: '원'),
                _LabeledField(label: '전체 전기사용량', controller: _elecUsage, color: BillyColors.electricity, suffix: 'kWh'),
              ),
              const SizedBox(height: 12),
              _field2(
                _LabeledField(label: '전체 수도요금', controller: _waterCost, color: BillyColors.water, suffix: '원'),
                _LabeledField(label: '전체 수도사용량', controller: _waterUsage, color: BillyColors.water, suffix: '㎥'),
              ),
              const SizedBox(height: 12),
              _field2(
                _LabeledField(label: '상수도 요금', controller: _waterSupply, color: BillyColors.water, suffix: '원'),
                _LabeledField(label: '하수도 요금', controller: _waterSewer, color: BillyColors.water, suffix: '원'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: AsyncButton(label: '관리비 계산하기', icon: Icons.calculate_rounded, onPressed: _calculate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_results.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              gradient: BillyColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: BillyColors.glow(BillyColors.headerEnd),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${chargeMonthLabel(p.chargeMonth)} 총 관리비',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(won(totalSum),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: BillyColors.primary,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('엑셀', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: AsyncButton(
              label: '이번 계산 내역 저장',
              icon: Icons.bookmark_added_outlined,
              color: BillyColors.success,
              onPressed: _saveHistory,
            ),
          ),
          const SizedBox(height: 14),
          ..._results.map((r) => _ResultCard(result: r, building: p)),
        ],
      ],
    );
  }

  Widget _field2(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 380
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );

  /// 업로드한 고지서 사진 썸네일(탭하면 확대). 인식 숫자와 비교해 직접 수정 가능.
  Widget _billThumb(BuildContext context, String label, ({String data, String media}) photo, Color color) {
    final bytes = base64Decode(photo.data);
    return SizedBox(
      width: 104,
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(child: Image.memory(bytes)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.image_outlined, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color))),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                Image.memory(bytes, height: 64, width: 104, fit: BoxFit.cover),
              const Positioned(
                right: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(6))),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('탭하면 확대',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final String suffix;
  const _LabeledField({required this.label, required this.controller, required this.color, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: '0', suffixText: suffix, isDense: true),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final CalcResult result;
  final AppProvider building;
  const _ResultCard({required this.result, required this.building});

  String _roomName() {
    for (final r in building.rooms) {
      if (r.roomNumber == result.roomNumber) return r.roomName;
    }
    return '${result.roomNumber}호';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          shape: const RoundedRectangleBorder(),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
            child: Text('${result.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          title: Text(_roomName(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          subtitle: Text(won(result.totalCost),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BillyColors.primary)),
          children: [
            _group('전기', BillyColors.electricity, [
              KeyValueRow('사용 전기료', won(result.electricityCost)),
              KeyValueRow('공동 전기료', won(result.electricityCostCommon)),
              KeyValueRow('부가세(10%)', won(result.electricityCostTax)),
              KeyValueRow('전력기금(2.7%)', won(result.electricityCostFund)),
              KeyValueRow('전기 합계', won(result.electricityCostTotal), bold: true, valueColor: BillyColors.electricity),
            ]),
            const SizedBox(height: 8),
            _group('수도', BillyColors.water, [
              KeyValueRow('상수도', won(result.waterCostSupply)),
              KeyValueRow('하수도', won(result.waterCostSewer)),
              KeyValueRow('공동 수도', won(result.waterCostCommon)),
              KeyValueRow('수도 합계', won(result.waterCostTotal), bold: true, valueColor: BillyColors.water),
            ]),
            const Divider(height: 20),
            KeyValueRow('총 합계', won(result.totalCost), bold: true, valueColor: BillyColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            ]),
          ),
          ...rows,
        ],
      ),
    );
  }
}
