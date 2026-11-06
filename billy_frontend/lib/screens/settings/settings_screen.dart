import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/shell.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// 설정 — 관리비 항목(요금표) · 명세서 · 건물 정보.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _build = String.fromEnvironment('BUILD_NUMBER');

  @override
  Widget build(BuildContext context) {
    final bid = context.watch<AppProvider>().buildingId;
    Widget tile(IconData icon, String title, String subtitle, String path) => ListTile(
          leading: CircleAvatar(backgroundColor: BillyColors.primarySoft, child: Icon(icon, color: BillyColors.primary, size: 20)),
          title: Text(title, style: BillyText.bodyStrong),
          subtitle: Text(subtitle, style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
          onTap: () => context.go('/b/$bid/settings/$path'),
        );
    return Scaffold(
      appBar: buildingAppBar(context, '설정'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, BillySpace.xxxl),
        children: [
          ContentWidth(
            max: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BillyCard(
                  padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
                  child: Column(children: [
                    tile(Icons.tune_rounded, '관리비 항목', '항목·나누는 방식·요율을 우리 건물에 맞게', 'plan'),
                    const Divider(height: 1),
                    tile(Icons.description_outlined, '명세서', '관리소 표기·납부 장소·계좌·공지·연체율', 'statement'),
                    const Divider(height: 1),
                    tile(Icons.apartment_rounded, '건물 정보', '이름·주소·층수', 'building'),
                  ]),
                ),
                const SizedBox(height: BillySpace.lg),
                BillyCard(
                  padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.swap_horiz_rounded),
                      title: const Text('다른 건물 보기'),
                      onTap: () => context.go('/'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded, color: BillyColors.error),
                      title: Text('로그아웃', style: BillyText.body.copyWith(color: BillyColors.error)),
                      subtitle: Text(AuthService.currentUser?.username ?? '', style: BillyText.caption),
                      onTap: () async {
                        await AuthService.clear();
                        if (!context.mounted) return;
                        context.read<AppProvider>().clear();
                        authState.value = false;
                        context.go('/login');
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: BillySpace.lg),
                Center(child: Text('Billy${_build.isEmpty ? '' : ' · 빌드 $_build'}', style: BillyText.caption.copyWith(color: BillyColors.textHint))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
