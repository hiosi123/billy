import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'providers/app_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

/// 전역 네비게이터 — 401(토큰 만료) 시 context 없이 로그인 화면으로 보내기 위함.
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await AuthService.init();

  // 토큰 만료/무효(401) → 세션 정리 후 로그인 화면으로 (어정쩡한 빈 화면 방지).
  ApiService.onUnauthorized = () async {
    await AuthService.clear();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('세션이 만료되어 다시 로그인해 주세요.')));
  };

  runApp(const BillyApp());
}

class BillyApp extends StatelessWidget {
  const BillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'Billy — 건물 관리비',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        initialRoute: AuthService.isLoggedIn ? '/home' : '/',
        routes: {
          '/': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}
