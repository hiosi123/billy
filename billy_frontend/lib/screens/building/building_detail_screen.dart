import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'rooms_tab.dart';
import 'measure_tab.dart';
import 'calculate_tab.dart';
import 'history_tab.dart';
import 'fee_settings_tab.dart';

class BuildingDetailScreen extends StatelessWidget {
  const BuildingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final b = p.selectedBuilding;
    if (b == null) {
      return const Scaffold(body: Center(child: Text('건물을 선택해주세요')));
    }
    final totalSpace = p.floors.fold<double>(0, (s, f) => s + f.floorSpace);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: BillyColors.headerEnd,
        body: Column(
          children: [
            // ── 다크 네이비 헤더 + KPI ───────────────────────────
            Container(
              decoration: const BoxDecoration(gradient: BillyColors.headerGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.buildingName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                                Text(b.buildingAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '새로고침',
                            onPressed: () => p.loadDetail(),
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            _kpi('호실', '${p.rooms.length}'),
                            const SizedBox(width: 10),
                            _kpi('층', '${p.floors.length}'),
                            const SizedBox(width: 10),
                            _kpi('총 면적', '${num2(totalSpace)}㎡'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── 화이트 시트 (탭) ──────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: BillyColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Material(
                      color: Colors.white,
                      child: const TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: BillyColors.headerEnd,
                        unselectedLabelColor: BillyColors.textSecondary,
                        indicatorColor: BillyColors.headerEnd,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                        tabs: [
                          Tab(text: '호실'),
                          Tab(text: '검침 입력'),
                          Tab(text: '관리비 계산'),
                          Tab(text: '관리비 내역'),
                          Tab(text: '관리비 설정'),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: p.loadingDetail && p.rooms.isEmpty && p.floors.isEmpty
                          ? const LoadingView()
                          : const TabBarView(
                              children: [
                                RoomsTab(),
                                MeasureTab(),
                                CalculateTab(),
                                HistoryTab(),
                                FeeSettingsTab(),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
