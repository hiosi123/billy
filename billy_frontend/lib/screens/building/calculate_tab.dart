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

  @override
  void dispose() {
    for (final c in [_elecCost, _elecUsage, _waterCost, _waterUsage, _waterSupply, _waterSewer]) {
      c.dispose();
    }
    super.dispose();
  }

  // 콤마가 섞여 있어도 안전하게 숫자로 파싱.
  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  /// 공공요금 고지서 사진 → AI OCR → 합계 입력칸 자동 채움. (type: 'water'|'electricity')
  Future<void> _readBill(String type) async {
    final picked = await pickImageBase64(context, maxWidth: 2400); // 고지서는 글자가 작아 고해상도
    if (picked == null || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final r = await api.readBill(image: picked.data, type: type, mediaType: picked.media);
      if (!mounted) return;
      var filled = 0;
      void fill(TextEditingController c, dynamic v) {
        if (v is num) {
          c.text = money(v);
          filled++;
        }
      }
      if (type == 'water') {
        fill(_waterUsage, r['waterTotalUsage']);
        fill(_waterSupply, r['waterSupplyCost']);
        fill(_waterSewer, r['waterSewerCost']);
        fill(_waterCost, r['waterTotalCost']);
      } else {
        fill(_elecCost, r['electricityTotalCost']);
        fill(_elecUsage, r['electricityTotalUsage']);
      }
      setState(() {});
      showSnack(context, filled > 0 ? '고지서에서 $filled개 항목을 입력했습니다 (확인 후 계산)' : '고지서에서 값을 인식하지 못했습니다',
          error: filled == 0);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
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
                          child: Text('고지서 사진을 찍으면 AI가 합계를 자동 입력합니다',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BillyColors.primaryDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '수도 고지서',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.water,
                              onPressed: () => _readBill('water'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '전기 고지서',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.electricity,
                              onPressed: () => _readBill('electricity'),
                            ),
                          ),
                        ),
                      ],
                    ),
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
              gradient: BillyColors.brandGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: BillyColors.glow(BillyColors.primary),
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
