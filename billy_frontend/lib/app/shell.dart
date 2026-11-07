import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// 건물 화면 틀 — 폰(좁은 화면)은 아래 탭, 넓은 화면은 왼쪽 메뉴. 탭: 이번 달 · 정산 · 호실 · 설정.
class BuildingShell extends StatefulWidget {
  final int buildingId;
  final String location;
  final Widget child;
  const BuildingShell({super.key, required this.buildingId, required this.location, required this.child});

  @override
  State<BuildingShell> createState() => _BuildingShellState();
}

class _BuildingShellState extends State<BuildingShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().openBuilding(widget.buildingId));
  }

  @override
  void didUpdateWidget(covariant BuildingShell old) {
    super.didUpdateWidget(old);
    if (old.buildingId != widget.buildingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().openBuilding(widget.buildingId));
    }
  }

  int get _index {
    final l = widget.location;
    if (l.contains('/settle')) return 1;
    if (l.contains('/units')) return 2;
    if (l.contains('/settings')) return 3;
    return 0;
  }

  void _go(int i) {
    final p = context.read<AppProvider>();
    final b = widget.buildingId;
    switch (i) {
      case 0:
        context.go('/b/$b/home');
      case 1:
        context.go('/b/$b/settle/${p.workingMonth}');
      case 2:
        context.go('/b/$b/units');
      case 3:
        context.go('/b/$b/settings');
    }
  }

  static const _dests = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, '이번 달'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, '정산'),
    (Icons.meeting_room_outlined, Icons.meeting_room_rounded, '호실'),
    (Icons.tune_outlined, Icons.tune_rounded, '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final ready = p.building?.buildingId == widget.buildingId && !p.loadingBuilding;
    final Widget body;
    if (p.buildingError != null && !p.loadingBuilding) {
      body = Scaffold(
        appBar: AppBar(title: const Text('건물')),
        body: Padding(
          padding: const EdgeInsets.all(BillySpace.lg),
          child: ErrorBanner(message: '건물을 불러오지 못했습니다: ${errorText(p.buildingError!)}', onRetry: () => p.openBuilding(widget.buildingId, force: true)),
        ),
      );
    } else if (!ready) {
      body = const Scaffold(body: LoadingView());
    } else {
      body = widget.child;
    }

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) {
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _go,
            destinations: [for (final d in _dests) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
          ),
        );
      }
      final extended = c.maxWidth >= 1100;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: 200,
              selectedIndex: _index,
              onDestinationSelected: _go,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(BillySpace.sm, BillySpace.md, BillySpace.sm, BillySpace.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(BillyRadius.md),
                  onTap: () => context.go('/'),
                  child: Padding(
                    padding: const EdgeInsets.all(BillySpace.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(gradient: BillyColors.headerGradient, borderRadius: BorderRadius.circular(BillyRadius.sm)),
                          child: const Icon(Icons.apartment_rounded, color: BillyColors.onDark, size: 20),
                        ),
                        if (extended) ...[
                          const SizedBox(width: BillySpace.sm),
                          SizedBox(
                            width: 120,
                            child: Text(p.building?.buildingName ?? 'Billy', style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _dests) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    });
  }
}

/// 화면 위 제목 줄 — 건물 이름(누르면 건물 목록) + 화면 제목 + 동작.
/// [back] 이 있으면 설정 안쪽 화면처럼 왼쪽에 뒤로 단추를 둔다(폰에서 돌아갈 길).
PreferredSizeWidget buildingAppBar(BuildContext context, String title, {List<Widget>? actions, PreferredSizeWidget? bottom, String? back}) {
  final b = context.watch<AppProvider>().building;
  return AppBar(
    automaticallyImplyLeading: false,
    leading: back == null ? null : IconButton(tooltip: '뒤로', onPressed: () => context.go(back), icon: const Icon(Icons.arrow_back_rounded)),
    titleSpacing: back == null ? BillySpace.gutter : 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(b?.buildingName ?? '', style: BillyText.caption.copyWith(color: BillyColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.unfold_more_rounded, size: 14, color: BillyColors.textSecondary),
            ],
          ),
        ),
        Text(title, style: BillyText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}
