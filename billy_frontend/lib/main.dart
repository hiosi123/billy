import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'providers/app_provider.dart';
import 'app/router.dart';
import 'screens/buildings/buildings_screen.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await AuthService.init();

  // 토큰 만료/무효(401) → 세션 정리 후 로그인 화면으로 (어정쩡한 빈 화면 방지).
  ApiService.onUnauthorized = () async {
    await AuthService.clear();
    BuildingsScreen.autoOpened = false;
    authState.value = false;
    router.go('/login');
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
      child: MaterialApp.router(
        title: 'Billy — 건물 관리',
        scaffoldMessengerKey: scaffoldMessengerKey,
        theme: AppTheme.light,
        // 달력·복사 메뉴 등 Material 기본 글이 영어로 나오지 않게(입금일 달력이 'Select date'였다)
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}
