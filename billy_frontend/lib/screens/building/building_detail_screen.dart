import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/common.dart';
import 'rooms_tab.dart';
import 'measure_tab.dart';
import 'calculate_tab.dart';
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

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.buildingName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(b.buildingAddress,
                  style: const TextStyle(fontSize: 11.5, color: BillyColors.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: () => p.loadDetail(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: BillyColors.primary,
            unselectedLabelColor: BillyColors.textSecondary,
            indicatorColor: BillyColors.primary,
            indicatorWeight: 2.5,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: '호실'),
              Tab(text: '검침 입력'),
              Tab(text: '관리비 계산'),
              Tab(text: '관리비 설정'),
            ],
          ),
        ),
        body: p.loadingDetail && p.rooms.isEmpty && p.floors.isEmpty
            ? const LoadingView()
            : const TabBarView(
                children: [
                  RoomsTab(),
                  MeasureTab(),
                  CalculateTab(),
                  FeeSettingsTab(),
                ],
              ),
      ),
    );
  }
}
