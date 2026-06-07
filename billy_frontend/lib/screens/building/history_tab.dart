import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/bill_history.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../services/file_saver.dart';
import 'month_selector.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<BillHistory> _histories = [];
  bool _loading = false;
  bool _monthMode = false; // 월별 조회 결과면 엑셀 다운로드 가능
  String _loadedMonth = '';

  Future<void> _loadByMonth() async {
    final p = context.read<AppProvider>();
    setState(() => _loading = true);
    try {
      final list = await p.api.getBillHistoriesByMonth(p.chargeMonth, p.selectedBuilding!.buildingId);
      setState(() {
        _histories = list..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
        _monthMode = true;
        _loadedMonth = p.chargeMonth;
      });
      if (mounted && list.isEmpty) showSnack(context, '${chargeMonthLabel(p.chargeMonth)} 저장된 내역이 없습니다');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAll() async {
    final p = context.read<AppProvider>();
    setState(() => _loading = true);
    try {
      final all = await p.api.getAllBillHistories();
      final mine = all.where((h) => h.buildingId == p.selectedBuilding!.buildingId).toList()
        ..sort((a, b) {
          final m = b.chargeMonth.compareTo(a.chargeMonth);
          return m != 0 ? m : a.roomNumber.compareTo(b.roomNumber);
        });
      setState(() {
        _histories = mine;
        _monthMode = false;
      });
      if (mounted && mine.isEmpty) showSnack(context, '저장된 내역이 없습니다');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadExcel() async {
    final p = context.read<AppProvider>();
    if (_histories.isEmpty) return;
    try {
      final bytes = await p.api.makeBillExcel(_histories.map((e) => e.toExcelJson()).toList());
      final name = await saveXlsx(bytes, '관리비내역_$_loadedMonth.xlsx');
      if (mounted) showSnack(context, '엑셀 명세서 생성 완료 ($name)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalElec = _histories.fold<double>(0, (s, h) => s + h.electricityCostTotal);
    final totalWater = _histories.fold<double>(0, (s, h) => s + h.waterCostTotal);
    final grandTotal = _histories.fold<double>(0, (s, h) => s + h.totalCost);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        MonthSelector(month: p.chargeMonth, onChanged: (m) => p.setChargeMonth(m)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AsyncButton(label: '월별 내역 조회', icon: Icons.search_rounded, onPressed: _loadByMonth)),
            const SizedBox(width: 10),
            Expanded(
              child: AsyncButton(label: '전체 내역 조회', icon: Icons.history_rounded, outlined: true, onPressed: _loadAll),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const LoadingView()
        else if (_histories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(
              icon: Icons.receipt_long_outlined,
              message: '조회 버튼을 눌러 저장된 관리비 내역을 확인하세요.\n(계산 탭에서 계산 후 "내역 저장"하면 여기에 쌓입니다)',
            ),
          )
        else ...[
          // 통계 요약
          Container(
            decoration: BoxDecoration(
              gradient: BillyColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: BillyColors.glow(BillyColors.headerEnd),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _monthMode ? '${chargeMonthLabel(_loadedMonth)} 관리비 합계' : '전체 내역 합계',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_monthMode)
                      ElevatedButton.icon(
                        onPressed: _downloadExcel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: BillyColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('엑셀', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryStat('호실', '${_histories.length}'),
                    _summaryStat('전기 총액', money(totalElec)),
                    _summaryStat('수도 총액', money(totalWater)),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(won(grandTotal),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._histories.map((h) => _HistoryCard(history: h, showMonth: !_monthMode, roomName: _roomName(p, h.roomNumber))),
        ],
      ],
    );
  }

  String _roomName(AppProvider p, int roomNumber) {
    for (final r in p.rooms) {
      if (r.roomNumber == roomNumber) return r.roomName;
    }
    return '$roomNumber호';
  }

  Widget _summaryStat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  final BillHistory history;
  final bool showMonth;
  final String roomName;
  const _HistoryCard({required this.history, required this.showMonth, required this.roomName});

  @override
  Widget build(BuildContext context) {
    final h = history;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
            child: Text('${h.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          title: Text(roomName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          subtitle: Text(
            '${showMonth ? '${chargeMonthLabel(h.chargeMonth)} · ' : ''}${won(h.totalCost)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BillyColors.primary),
          ),
          children: [
            _group('전기', BillyColors.electricity, [
              KeyValueRow('기본 전기료', won(h.electricityCost)),
              KeyValueRow('공용 전기료', won(h.electricityCostCommon)),
              KeyValueRow('부가세', won(h.electricityCostTax)),
              KeyValueRow('기금', won(h.electricityCostFund)),
              KeyValueRow('전기 합계', won(h.electricityCostTotal), bold: true, valueColor: BillyColors.electricity),
            ]),
            const SizedBox(height: 8),
            _group('수도', BillyColors.water, [
              KeyValueRow('상수도', won(h.waterCostSupply)),
              KeyValueRow('하수도', won(h.waterCostSewer)),
              KeyValueRow('공용 수도', won(h.waterCostCommon)),
              KeyValueRow('수도 합계', won(h.waterCostTotal), bold: true, valueColor: BillyColors.water),
            ]),
            const Divider(height: 20),
            KeyValueRow('총 합계', won(h.totalCost), bold: true, valueColor: BillyColors.primary),
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
