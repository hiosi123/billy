import 'package:flutter/material.dart';

/// Billy 디자인 시스템 — 업무용 도구. 숫자 가독성과 신뢰감 있는 절제된 톤.
/// 화면에서는 색·글자·간격을 여기 토큰으로만 쓴다(하드코딩 금지).
class BillyColors {
  // 브랜드 블루
  static const primary = Color(0xFF2563EB); // blue-600 (포인트)
  static const primaryDark = Color(0xFF1E3A8A); // navy-900
  static const primaryStart = Color(0xFF1E40AF); // 그라데이션 진한 쪽
  static const primaryEnd = Color(0xFF3B82F6); // 그라데이션 밝은 쪽
  static const primarySoft = Color(0xFFE8EFFE); // 아주 옅은 블루(칩/배경)

  // 카테고리 색 (명세서 묶음 구분용)
  static const electricity = Color(0xFFD97706); // 전기 = 앰버(글자 대비 확보한 진한 톤)
  static const electricitySoft = Color(0xFFFEF3E2);
  static const water = Color(0xFF0284C7); // 수도 = 스카이
  static const waterSoft = Color(0xFFE3F4FD);
  static const fee = Color(0xFF7C3AED); // 관리비 = 바이올렛
  static const feeSoft = Color(0xFFF1ECFE);

  // 상태색
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFEAF7EE);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFF7E6);
  static const error = Color(0xFFDC2626);
  static const errorSoft = Color(0xFFFEF2F2); // 경고·오류 상자 배경

  // 배경 / 표면
  static const background = Color(0xFFF4F6FB); // 쿨 그레이
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8FAFC); // 표 줄무늬 등
  static const onDark = Color(0xFFFFFFFF); // 네이비 헤더 위 글자
  static const onDarkMuted = Color(0xB3FFFFFF); // 네이비 헤더 위 보조 글자(70%)
  static const onDarkFaint = Color(0x1FFFFFFF); // 네이비 헤더 위 칸 배경(12%)

  // 텍스트 (슬레이트 계열)
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const scrim = Color(0x8A000000); // 사진 위 글자 띠
  static const photoBackdrop = Color(0xFF000000); // 사진 크게 보기 배경

  // 역할 배지
  static const adminColor = Color(0xFF2563EB);
  static const managerColor = Color(0xFF0EA5E9);
  static const viewerColor = Color(0xFF94A3B8);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryStart, primaryEnd],
  );

  // 다크 헤더 대시보드 — 네이비 헤더(시안 B)
  static const headerStart = Color(0xFF1B2A4A);
  static const headerEnd = Color(0xFF2D4A7C);
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment(-0.8, -1),
    end: Alignment(1, 1),
    colors: [headerStart, headerEnd],
  );

  /// 묶음(관리비·전기·수도·기타) 색 — 명세서 소계 구분.
  static Color group(String code) => switch (code) {
        'electricity' => electricity,
        'water' => water,
        'fee' => fee,
        _ => primary,
      };
  static Color groupSoft(String code) => switch (code) {
        'electricity' => electricitySoft,
        'water' => waterSoft,
        'fee' => feeSoft,
        _ => primarySoft,
      };

  static List<BoxShadow> get cardShadow => [
        BoxShadow(color: textPrimary.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        BoxShadow(color: textPrimary.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1)),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -4),
      ];

  static BoxDecoration card({Color? color, BorderRadius? radius, List<BoxShadow>? shadows}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: radius ?? BorderRadius.circular(BillyRadius.lg),
        border: Border.all(color: border, width: 1),
        boxShadow: shadows ?? cardShadow,
      );
}

/// 간격 단계(4의 배수).
class BillySpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  /// 폰 좌우 여백 / 넓은 화면 최대 폭.
  static const gutter = 16.0;
  static const maxContent = 1100.0;
}

class BillyRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

/// 글자 단계 — 굵기는 번들 폰트(400·700) 두 가지만 쓴다. 최소 11px(작은 글씨는 어르신 사용자에게 힘들다).
class BillyText {
  static const _f = 'NotoSansKR';
  static const tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.4);
  static const headline = TextStyle(fontFamily: _f, fontSize: 21, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.3);
  static const title = TextStyle(fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: -0.2);
  static const subtitle = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4);
  static const body = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static const bodyStrong = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700, height: 1.5);
  static const caption = TextStyle(fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.45);
  static const captionStrong = TextStyle(fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.45);
  static const tiny = TextStyle(fontFamily: _f, fontSize: 11, fontWeight: FontWeight.w700, height: 1.35, letterSpacing: 0.1);

  /// 금액 — 자릿수가 맞게 고정폭 숫자.
  static TextStyle money(double size, {Color color = BillyColors.textPrimary, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: _f, fontSize: size, fontWeight: weight, color: color, fontFeatures: tabular, letterSpacing: -0.2);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: BillyColors.primary,
      primary: BillyColors.primary,
      secondary: BillyColors.water,
      surface: BillyColors.surface,
      error: BillyColors.error,
    );
    OutlineInputBorder outline(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(BillyRadius.md), borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansKR',
      colorScheme: scheme,
      scaffoldBackgroundColor: BillyColors.background,
      textTheme: const TextTheme(
        headlineSmall: BillyText.headline,
        titleLarge: BillyText.title,
        titleMedium: BillyText.subtitle,
        bodyLarge: BillyText.body,
        bodyMedium: BillyText.body,
        bodySmall: BillyText.caption,
        labelLarge: BillyText.bodyStrong,
      ).apply(bodyColor: BillyColors.textPrimary, displayColor: BillyColors.textPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: BillyColors.surface,
        foregroundColor: BillyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'NotoSansKR', color: BillyColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        iconTheme: IconThemeData(color: BillyColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: BillyColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BillyRadius.lg),
          side: const BorderSide(color: BillyColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.md)),
          textStyle: BillyText.bodyStrong,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BillyColors.primary,
          foregroundColor: BillyColors.onDark,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.md)),
          textStyle: BillyText.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: BillyColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.md)),
          textStyle: BillyText.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(textStyle: BillyText.bodyStrong)),
      inputDecorationTheme: InputDecorationTheme(
        // 칸 아래 도움말·오류가 한 줄에서 '…'로 잘리지 않게(폰 폭·큰 글자)
        helperMaxLines: 2,
        errorMaxLines: 3,
        filled: true,
        fillColor: BillyColors.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: BillyText.body.copyWith(color: BillyColors.textSecondary),
        hintStyle: BillyText.body.copyWith(color: BillyColors.textHint),
        border: outline(BillyColors.border),
        enabledBorder: outline(BillyColors.border),
        focusedBorder: outline(BillyColors.primary, 1.6),
        errorBorder: outline(BillyColors.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BillyColors.surface,
        indicatorColor: BillyColors.primarySoft,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => BillyText.tiny.copyWith(
              color: s.contains(WidgetState.selected) ? BillyColors.primary : BillyColors.textSecondary,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? BillyColors.primary : BillyColors.textSecondary,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: BillyColors.surface,
        indicatorColor: BillyColors.primarySoft,
        selectedIconTheme: const IconThemeData(color: BillyColors.primary),
        unselectedIconTheme: const IconThemeData(color: BillyColors.textSecondary),
        selectedLabelTextStyle: BillyText.captionStrong.copyWith(color: BillyColors.primary),
        unselectedLabelTextStyle: BillyText.caption.copyWith(color: BillyColors.textSecondary),
      ),
      dividerTheme: const DividerThemeData(color: BillyColors.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: BillyText.body.copyWith(color: BillyColors.onDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: BillyColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.xl)),
        titleTextStyle: BillyText.title.copyWith(color: BillyColors.textPrimary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BillyColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BillyRadius.xl))),
      ),
      chipTheme: ChipThemeData(
        labelStyle: BillyText.captionStrong,
        side: const BorderSide(color: BillyColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.sm)),
      ),
    );
  }
}
