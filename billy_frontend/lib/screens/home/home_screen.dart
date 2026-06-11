import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart';
import '../../models/building.dart';
import '../../widgets/common.dart';
import '../building/building_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().loadBuildings());
  }

  Future<void> _logout() async {
    await AuthService.clear();
    if (!mounted) return;
    context.read<AppProvider>().reset();
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final p = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: BillyColors.headerEnd,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBuilding(context),
        backgroundColor: BillyColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('건물 추가', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── 다크 네이비 헤더 ───────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: BillyColors.headerGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Text('Billy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        const Spacer(),
                        if (user != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(user.username,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        IconButton(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
                          tooltip: '로그아웃',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('관리 중인 건물',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${p.buildings.length}개',
                                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.domain_rounded, color: Colors.white, size: 27),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── 화이트 시트 (건물 목록) ─────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: BillyColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: RefreshIndicator(
                onRefresh: () => p.loadBuildings(),
                child: p.loadingBuildings && p.buildings.isEmpty
                    ? const LoadingView()
                    : p.buildings.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 60),
                            EmptyView(
                              icon: Icons.apartment_outlined,
                              message: '등록된 건물이 없습니다.\n오른쪽 아래 버튼으로 건물을 추가해보세요.',
                              action: FilledButton.icon(
                                onPressed: () => _showAddBuilding(context),
                                icon: const Icon(Icons.add),
                                label: const Text('건물 추가'),
                              ),
                            ),
                            const SizedBox(height: 40),
                            const _AdInquiryFooter(),
                          ])
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                            children: [
                              ...p.buildings.map((b) => _BuildingCard(
                                    building: b,
                                    onTap: () async {
                                      await p.selectBuilding(b);
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const BuildingDetailScreen()),
                                      );
                                    },
                                    onDelete: () => _confirmDelete(context, b),
                                  )),
                              const SizedBox(height: 8),
                              const _AdInquiryFooter(),
                            ],
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Building b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('건물 삭제'),
        content: Text("'${b.buildingName}' 건물과 모든 층·호실·청구 데이터가 삭제됩니다. 계속할까요?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BillyColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await context.read<AppProvider>().deleteBuilding(b.buildingId);
        if (context.mounted) showSnack(context, '삭제되었습니다');
      } catch (e) {
        if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  void _showAddBuilding(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddBuildingSheet(),
    );
  }
}

/// 화면 하단의 작은 광고 문의 안내.
class _AdInquiryFooter extends StatelessWidget {
  const _AdInquiryFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 13, color: BillyColors.textHint),
            const SizedBox(width: 5),
            Text(
              '광고 문의  010-2031-1883',
              style: TextStyle(
                fontSize: 11.5,
                color: BillyColors.textHint,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final Building building;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _BuildingCard({required this.building, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: BillyColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.business_rounded, color: BillyColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.buildingName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BillyColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        building.buildingAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: BillyColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _miniInfo(Icons.layers_outlined, '${building.buildingFloors}층'),
                          const SizedBox(width: 12),
                          _miniInfo(Icons.person_outline, building.owner),
                          if (building.hasElevator) ...[
                            const SizedBox(width: 12),
                            _miniInfo(Icons.elevator_outlined, '엘리베이터'),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: BillyColors.textHint),
                ),
                const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: BillyColors.textHint),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11.5, color: BillyColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AddBuildingSheet extends StatefulWidget {
  const _AddBuildingSheet();

  @override
  State<_AddBuildingSheet> createState() => _AddBuildingSheetState();
}

class _AddBuildingSheetState extends State<_AddBuildingSheet> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _owner = TextEditingController();
  final _floors = TextEditingController(text: '1');
  bool _elevator = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _owner.dispose();
    _floors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: BillyColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              const Text('건물 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              TextField(controller: _name, decoration: const InputDecoration(labelText: '건물 이름')),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: const InputDecoration(labelText: '주소')),
              const SizedBox(height: 12),
              TextField(controller: _owner, decoration: const InputDecoration(labelText: '소유자')),
              const SizedBox(height: 12),
              TextField(
                controller: _floors,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '층수'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('엘리베이터', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _elevator,
                activeThumbColor: BillyColors.primary,
                onChanged: (v) => setState(() => _elevator = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: AsyncButton(
                  label: '추가하기',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty || _owner.text.trim().isEmpty) {
                      showSnack(context, '모든 항목을 입력해주세요', error: true);
                      return;
                    }
                    try {
                      await context.read<AppProvider>().createBuilding({
                        'buildingName': _name.text.trim(),
                        'buildingAddress': _address.text.trim(),
                        'owner': _owner.text.trim(),
                        'buildingFloors': int.tryParse(_floors.text) ?? 1,
                        'elevator': _elevator ? 1 : 0,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        showSnack(context, '건물이 추가되었습니다');
                      }
                    } catch (e) {
                      if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
