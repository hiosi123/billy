import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/buildings/buildings_screen.dart';
import '../screens/month/month_home_screen.dart';
import '../screens/settle/settle_screen.dart';
import '../screens/units/units_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/plan_editor_screen.dart';
import '../screens/settings/statement_settings_screen.dart';
import '../screens/settings/building_info_screen.dart';
import '../screens/settings/account_screen.dart';
import '../widgets/common.dart' show ModalWatch;
import '../widgets/ui.dart' show confirmAction;
import 'shell.dart';

/// 주소 체계 — 새로고침·뒤로가기·링크가 그대로 동작한다(예전엔 기기 저장소로 화면을 복원했다).
///   /login · / (건물 목록) · /b/:bid/home?m=YYYYMM · /b/:bid/settle/:month?step=readings|invoice|review|statements
///   /b/:bid/units · /b/:bid/settings(/plan|/statement|/building)
final authState = ValueNotifier<bool>(AuthService.isLoggedIn);

/// 로그아웃 — 토큰·건물 상태를 지우고 로그인 화면으로(설정·내 계정 공용).
Future<void> signOut(BuildContext context) async {
  await AuthService.clear();
  if (!context.mounted) return;
  context.read<AppProvider>().clear();
  BuildingsScreen.autoOpened = false; // 다시 로그인하면 건물이 하나일 때 바로 들어가게
  authState.value = false;
  context.go('/login');
}

/// 아래 탭(이번 달·정산·호실·설정)끼리는 밀려 들어오는 효과 없이 바로 바꾼다.
Page<void> _tab(GoRouterState s, Widget child) => NoTransitionPage(key: s.pageKey, child: child);

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: authState,
  // 예전 주소(#/home 등 북마크)나 없는 주소는 건물 목록으로 — 기본 영어 'Page Not Found' 화면을 띄우지 않는다.
  onException: (_, __, router) => router.go('/'),
  observers: [ModalWatch.instance],
  redirect: (context, state) {
    final loggedIn = AuthService.isLoggedIn;
    final atLogin = state.matchedLocation == '/login';
    if (!loggedIn && !atLogin) return '/login';
    if (loggedIn && atLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/', builder: (_, __) => const BuildingsScreen()),
    GoRoute(path: '/b/:bid', redirect: (_, s) => '/b/${s.pathParameters['bid']}/home'),
    ShellRoute(
      builder: (context, state, child) => BuildingShell(
        buildingId: int.tryParse(state.pathParameters['bid'] ?? '') ?? 0,
        location: state.matchedLocation,
        uri: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/b/:bid/home',
          pageBuilder: (_, s) => _tab(s, MonthHomeScreen(month: s.uri.queryParameters['m'])),
        ),
        GoRoute(
          path: '/b/:bid/settle/:month',
          // 아래 탭·뒤로가기로 나갈 때도 저장 안 한 검침·고지서 금액을 묻는다(단계·달 이동은 SettleScreen 이 묻는다)
          onExit: (context, _) => confirmLeaveSettle(context),
          pageBuilder: (_, s) => _tab(s, SettleScreen(month: s.pathParameters['month']!, step: s.uri.queryParameters['step'])),
        ),
        GoRoute(path: '/b/:bid/units', pageBuilder: (_, s) => _tab(s, const UnitsScreen())),
        GoRoute(
          path: '/b/:bid/settings',
          pageBuilder: (_, s) => _tab(s, const SettingsScreen()),
          // 안쪽 화면은 설정 위에 쌓는다 — 안드로이드 뒤로 키가 앱을 끄지 않고 설정으로 돌아가게(예전엔 형제 주소라 앱이 꺼졌다)
          routes: [
            GoRoute(
              path: 'plan',
              // 세션이 끝나 로그인으로 보낼 때는 묻지 않는다
              onExit: (context, _) async =>
                  !AuthService.isLoggedIn ||
                  !planEditorDirty.value ||
                  await confirmAction(context, title: '저장하지 않은 변경이 있습니다', message: '이 화면을 나가면 고친 내용은 사라집니다.', ok: '나가기'),
              builder: (_, __) => const PlanEditorScreen(),
            ),
            GoRoute(path: 'statement', builder: (_, __) => const StatementSettingsScreen()),
            GoRoute(path: 'building', builder: (_, __) => const BuildingInfoScreen()),
            GoRoute(path: 'account', builder: (_, __) => const AccountScreen()),
          ],
        ),
      ],
    ),
  ],
);
