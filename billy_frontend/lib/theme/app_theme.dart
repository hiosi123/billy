import 'package:flutter/material.dart';

/// Billy 디자인 시스템 — "프로페셔널 블루"
/// 건물주·관리자가 쓰는 업무용 도구. 표·숫자 가독성과 신뢰감 있는 톤 중심.
class BillyColors {
  // 브랜드 블루
  static const primary = Color(0xFF2563EB); // blue-600 (포인트)
  static const primaryDark = Color(0xFF1E3A8A); // navy-900
  static const primaryStart = Color(0xFF1E40AF); // 그라데이션 진한 쪽
  static const primaryEnd = Color(0xFF3B82F6); // 그라데이션 밝은 쪽
  static const primarySoft = Color(0xFFE8EFFE); // 아주 옅은 블루(칩/배경)

  // 카테고리 색 (명세서 구분용)
  static const electricity = Color(0xFFF59E0B); // 전기 = 앰버
  static const electricitySoft = Color(0xFFFEF3E2);
  static const water = Color(0xFF0EA5E9); // 수도 = 스카이
  static const waterSoft = Color(0xFFE3F4FD);
  static const fee = Color(0xFF8B5CF6); // 관리비 = 바이올렛
  static const feeSoft = Color(0xFFF1ECFE);

  // 상태색
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  // 배경 / 표면
  static const background = Color(0xFFF4F6FB); // 쿨 그레이
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC); // 표 줄무늬 등

  // 텍스트 (슬레이트 계열)
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);

  // 역할 배지
  static const adminColor = Color(0xFF2563EB);
  static const managerColor = Color(0xFF0EA5E9);
  static const viewerColor = Color(0xFF94A3B8);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryStart, primaryEnd],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  static BoxDecoration card({Color? color, BorderRadius? radius, List<BoxShadow>? shadows}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: radius ?? BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: shadows ?? cardShadow,
      );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.light(
          primary: BillyColors.primary,
          secondary: BillyColors.water,
          surface: BillyColors.surface,
          error: BillyColors.error,
        ),
        scaffoldBackgroundColor: BillyColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: BillyColors.surface,
          foregroundColor: BillyColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: BillyColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
          iconTheme: IconThemeData(color: BillyColors.textPrimary),
        ),
        cardTheme: CardThemeData(
          color: BillyColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: BillyColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.1),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: BillyColors.primary,
            side: const BorderSide(color: BillyColors.primary, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: BillyColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BillyColors.surface,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BillyColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BillyColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BillyColors.primary, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BillyColors.error, width: 1.4),
          ),
          labelStyle: const TextStyle(color: BillyColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 14),
          hintStyle: const TextStyle(color: BillyColors.textHint, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: BillyColors.primarySoft,
          labelStyle: const TextStyle(color: BillyColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        dividerTheme: const DividerThemeData(color: BillyColors.border, thickness: 1, space: 1),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: BillyColors.surface,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: BillyColors.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
}

String roleLabel(String? role) => {'admin': '관리자', 'manager': '매니저', 'viewer': '뷰어'}[role] ?? (role ?? '');
Color roleColor(String? role) => {
      'admin': BillyColors.adminColor,
      'manager': BillyColors.managerColor,
      'viewer': BillyColors.viewerColor,
    }[role] ??
    BillyColors.viewerColor;
