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
  final String uri; // 쿼리(?step=)까지 — 정산 탭이 마지막 자리로 돌아가게
  final Widget child;
  const BuildingShell({super.key, required this.buildingId, required this.location, required this.uri, required this.child});

  @override
  State<BuildingShell> createState() => _BuildingShellState();
}

class _BuildingShellState extends State<BuildingShell> {
  /// 마지막으로 본 정산 자리(달·단계). 정산 탭을 다시 누르면 여기로 — 예전엔 늘 '정산할 달' 검침으로 가서
  /// 9월분을 넣다 호실 탭에 다녀오면 10월분 검침이 열렸다(제목만 바뀌어 다른 달에 넣을 뻔했다).
  String? _lastSettle;

  @override
  void initState() {
    super.initState();
    _remember();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().openBuilding(widget.buildingId));
  }

  @override
  void didUpdateWidget(covariant BuildingShell old) {
    super.didUpdateWidget(old);
    if (old.buildingId != widget.buildingId) {
      _lastSettle = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppProvider>().openBuilding(widget.buildingId));
    }
    _remember();
  }

  void _remember() {
    if (widget.location.contains('/settle/')) _lastSettle = widget.uri;
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
        context.go(_lastSettle ?? '/b/$b/settle/${p.workingMonth}');
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
    // 불러오는 중·실패 화면에도 건물 목록으로 나가는 길을 둔다(예전엔 '다시 시도'만 있는 막다른 화면이었다)
    final toList = IconButton(tooltip: '건물 목록', onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back_rounded));
    if (p.buildingError != null && !p.loadingBuilding) {
      body = Scaffold(
        appBar: AppBar(leading: toList, title: const Text('건물')),
        body: ListView(
          padding: const EdgeInsets.all(BillySpace.lg),
          children: [
            ErrorBanner(message: '건물을 불러오지 못했습니다: ${errorText(p.buildingError!)}', onRetry: () => p.openBuilding(widget.buildingId, force: true)),
            const SizedBox(height: BillySpace.md),
            Center(child: OutlinedButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.apartment_rounded), label: const Text('건물 목록으로'))),
          ],
        ),
      );
    } else if (!ready) {
      body = Scaffold(appBar: AppBar(leading: toList), body: const LoadingView());
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
              // 좁은 데스크톱 폭(720~1099)에서도 아이콘 아래 이름을 보인다
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
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
                            // 다른 건물을 여는 중엔 옛 건물 이름을 보이지 않는다
                            child: Text(ready ? p.building!.buildingName : 'Billy', style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    // 설정 안쪽 화면은 설정 위에 쌓여 있다 — 꺼내서 돌아간다(새 주소로 가면 브라우저 뒤로가 다시 안쪽으로 돌아왔다)
    leading: back == null
        ? null
        : IconButton(tooltip: '뒤로', onPressed: () => context.canPop() ? context.pop() : context.go(back), icon: const Icon(Icons.arrow_back_rounded)),
    titleSpacing: back == null ? BillySpace.gutter : 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 건물 목록으로 가는 길 — 손가락으로 누르기 쉽게 위아래를 넓힌다(예전엔 글자 높이 18px 뿐)
        InkWell(
          onTap: () => context.go('/'),
          borderRadius: BorderRadius.circular(BillyRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
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
        ),
        Text(title, style: BillyText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}
