import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../models/building.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 건물 목록. 건물이 하나뿐이면 바로 그 건물로 들어간다(처음 열 때만).
class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  /// 건물이 하나면 처음 한 번만 바로 들어간다 — 로그아웃·세션 만료 때 다시 켠다.
  static bool autoOpened = false;

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = context.read<AppProvider>();
      await p.loadBuildings();
      if (!mounted) return;
      if (!BuildingsScreen.autoOpened && p.buildings.length == 1 && p.buildingsError == null) {
        BuildingsScreen.autoOpened = true;
        context.go('/b/${p.buildings.first.buildingId}/home');
      }
    });
  }

  Future<void> _logout() => signOut(context);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final user = AuthService.currentUser;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: BillySpace.gutter,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(gradient: BillyColors.headerGradient, borderRadius: BorderRadius.circular(BillyRadius.sm)),
              child: const Icon(Icons.apartment_rounded, color: BillyColors.onDark, size: 18),
            ),
            const SizedBox(width: BillySpace.sm),
            const Text('내 건물'),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: BillySpace.xs),
              child: Center(child: Text(user.username, style: BillyText.caption.copyWith(color: BillyColors.textSecondary))),
            ),
          IconButton(tooltip: '로그아웃', onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBuilding(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('건물 추가'),
      ),
      body: RefreshIndicator(
        onRefresh: p.loadBuildings,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, 120),
          children: [
            ContentWidth(
              max: 720,
              child: Column(
                children: [
                  if (p.loadingBuildings && p.buildings.isEmpty)
                    const LoadingView()
                  else if (p.buildingsError != null)
                    ErrorBanner(message: '건물 목록을 불러오지 못했습니다: ${errorText(p.buildingsError!)}', onRetry: p.loadBuildings)
                  else if (p.buildings.isEmpty)
                    const EmptyView(icon: Icons.apartment_rounded, message: '아직 건물이 없습니다.\n아래 [건물 추가]로 시작하세요.')
                  else
                    for (final b in p.buildings)
                      Padding(padding: const EdgeInsets.only(bottom: BillySpace.md), child: _BuildingCard(building: b)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBuilding(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const _AddBuildingSheet(),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final Building building;
  const _BuildingCard({required this.building});

  @override
  Widget build(BuildContext context) {
    final b = building;
    return BillyCard(
      onTap: () => context.go('/b/${b.buildingId}/home'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: BillyColors.primarySoft, borderRadius: BorderRadius.circular(BillyRadius.md)),
            child: const Icon(Icons.apartment_rounded, color: BillyColors.primary),
          ),
          const SizedBox(width: BillySpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.buildingName, style: BillyText.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [b.buildingAddress, '${b.buildingFloors}층'].where((s) => s.isNotEmpty).join(' · '),
                  style: BillyText.caption.copyWith(color: BillyColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            onSelected: (v) async {
              if (v != 'delete') return;
              final ok = await confirmTypedDelete(
                context,
                title: '건물 삭제',
                name: b.buildingName,
                detail: "'${b.buildingName}' 의 층·호실·검침·명세서가 모두 지워지고 되돌릴 수 없습니다.",
              );
              if (!ok || !context.mounted) return;
              try {
                await context.read<AppProvider>().deleteBuilding(b.buildingId);
                if (context.mounted) showSnack(context, '삭제했습니다');
              } catch (e) {
                if (context.mounted) showSnack(context, errorText(e), error: true);
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('건물 삭제'))],
          ),
        ],
      ),
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
  final _floors = TextEditingController(text: '1');
  final _owner = TextEditingController();
  bool _elevator = false;
  bool _saving = false; // 두 번 눌러 같은 건물이 둘 생기지 않게

  @override
  void dispose() {
    for (final c in [_name, _address, _floors, _owner]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      showSnack(context, '건물 이름을 입력해주세요', error: true);
      return;
    }
    final floors = int.tryParse(_floors.text.trim());
    if (floors == null || floors < 1) {
      showSnack(context, '층수는 1 이상의 숫자로 넣어 주세요', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final b = await context.read<AppProvider>().createBuilding({
        'buildingName': _name.text.trim(),
        'buildingAddress': _address.text.trim(),
        'buildingFloors': floors,
        'elevator': _elevator ? 1 : 0,
        'owner': _owner.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      context.go('/b/${b.buildingId}/units');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('건물 추가', style: BillyText.title),
            const SizedBox(height: BillySpace.xs),
            Text(keepAll('만든 뒤 호실·계량기를 등록하고, 설정에서 관리비 항목을 정합니다.'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            const SizedBox(height: BillySpace.lg),
            TextField(controller: _name, decoration: const InputDecoration(labelText: '건물 이름')),
            const SizedBox(height: BillySpace.md),
            TextField(controller: _address, decoration: const InputDecoration(labelText: '주소')),
            const SizedBox(height: BillySpace.md),
            Row(
              children: [
                Expanded(child: TextField(controller: _floors, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '층수'))),
                const SizedBox(width: BillySpace.md),
                Expanded(child: TextField(controller: _owner, decoration: const InputDecoration(labelText: '소유자'))),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('엘리베이터 있음'),
              value: _elevator,
              onChanged: (v) => setState(() => _elevator = v),
            ),
            const SizedBox(height: BillySpace.sm),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: BillyColors.primary))
                  : const Text('만들기'),
            ),
          ],
        ),
      ),
    );
  }
}
