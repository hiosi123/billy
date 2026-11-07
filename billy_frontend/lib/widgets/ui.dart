import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/v2.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// v2 공통 부품. 색·글자·간격은 theme 토큰만 쓴다.

final _won = NumberFormat('#,##0', 'ko_KR');

/// 금액 — 고정폭 숫자, 큰 글씨 설정에서도 칸을 넘지 않게 줄어든다.
class MoneyText extends StatelessWidget {
  final double amount;
  final double size;
  final Color color;
  final String suffix;
  final FontWeight weight;
  final bool signed;
  const MoneyText(this.amount,
      {super.key, this.size = 15, this.color = BillyColors.textPrimary, this.suffix = '원', this.weight = FontWeight.w700, this.signed = false});

  @override
  Widget build(BuildContext context) {
    final sign = signed && amount > 0 ? '+' : '';
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text('$sign${_won.format(amount.round())}$suffix', maxLines: 1, style: BillyText.money(size, color: color, weight: weight)),
    );
  }
}

String wonText(num v) => '${_won.format(v.round())}원';

/// 흰 카드.
class BillyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const BillyCard({super.key, required this.child, this.padding = const EdgeInsets.all(BillySpace.lg), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? BillyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BillyRadius.lg),
        side: const BorderSide(color: BillyColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// 섹션 제목(+ 오른쪽 동작).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, BillySpace.lg, 2, BillySpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BillyText.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!, style: BillyText.caption.copyWith(color: BillyColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

enum Tone { ok, warn, error, info, neutral }

Color toneColor(Tone t) => switch (t) {
      Tone.ok => BillyColors.success,
      Tone.warn => BillyColors.warning,
      Tone.error => BillyColors.error,
      Tone.info => BillyColors.primary,
      Tone.neutral => BillyColors.textSecondary,
    };
Color toneSoft(Tone t) => switch (t) {
      Tone.ok => BillyColors.successSoft,
      Tone.warn => BillyColors.warningSoft,
      Tone.error => BillyColors.errorSoft,
      Tone.info => BillyColors.primarySoft,
      Tone.neutral => BillyColors.surfaceAlt,
    };

/// 상태 칩(완료·필요·오류).
class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final IconData? icon;
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = toneColor(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: toneSoft(tone), borderRadius: BorderRadius.circular(BillyRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
          Text(label, style: BillyText.tiny.copyWith(color: c), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// 문제 목록(오류 빨강·주의 주황).
class IssueList extends StatelessWidget {
  final List<Issue> issues;
  const IssueList(this.issues, {super.key});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final i in issues)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: BillySpace.sm),
            padding: const EdgeInsets.all(BillySpace.md),
            decoration: BoxDecoration(
              color: i.error ? BillyColors.errorSoft : BillyColors.warningSoft,
              borderRadius: BorderRadius.circular(BillyRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(i.error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                    size: 18, color: i.error ? BillyColors.error : BillyColors.warning),
                const SizedBox(width: BillySpace.sm),
                Expanded(
                  child: Text(i.message,
                      style: BillyText.caption.copyWith(color: i.error ? BillyColors.error : BillyColors.textPrimary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 월 선택(◀ 2026년 9월분 ▶). 사용월 기준 — 고지월은 다음 달.
class MonthStepper extends StatelessWidget {
  final String month;
  final ValueChanged<String> onChanged;
  final bool dense;
  const MonthStepper({super.key, required this.month, required this.onChanged, this.dense = false});

  static String shift(String yyyymm, int delta) {
    final y = int.parse(yyyymm.substring(0, 4));
    final m = int.parse(yyyymm.substring(4, 6));
    final d = DateTime(y, m + delta, 1);
    return '${d.year}${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BillyColors.surface,
        borderRadius: BorderRadius.circular(BillyRadius.md),
        border: Border.all(color: BillyColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '이전 달',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(shift(month, -1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(monthLabel(month), style: dense ? BillyText.bodyStrong : BillyText.subtitle, maxLines: 1),
          ),
          IconButton(
            tooltip: '다음 달',
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(shift(month, 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// '면적 118.8m² · 1층' 같은 한 줄 요약. 항목 사이에서만 줄을 바꾼다
/// (그냥 Text 면 폰에서 '1' 과 '층' 사이가 끊긴다).
/// 단위는 ㎡·㎥ 대신 m²·m³ — 내장 글꼴에 ㎡·㎥ 가 없어 웹에선 글꼴 서버에서 늦게 받아 와 잠깐 빈칸이 된다.
class DotLine extends StatelessWidget {
  final List<String> parts;
  final TextStyle? style;
  const DotLine(this.parts, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final s = style ?? BillyText.caption.copyWith(color: BillyColors.textSecondary);
    return Wrap(children: [
      for (var i = 0; i < parts.length; i++)
        Text(i < parts.length - 1 ? '${parts[i]} · ' : parts[i], style: s, softWrap: false, overflow: TextOverflow.ellipsis),
    ]);
  }
}

/// 'YYYYMM' → '2026년 9월분'
String monthLabel(String yyyymm) => '${chargeMonthLabel(yyyymm)}분';

/// 'YYYYMM' → '9월분'
String shortMonth(String yyyymm) => yyyymm.length == 6 ? '${int.parse(yyyymm.substring(4, 6))}월분' : yyyymm;

/// 화면 아래 고정 버튼 바(폰에서 저장 버튼이 목록 위로 사라지지 않게).
class StickyActionBar extends StatelessWidget {
  final List<Widget> children;
  final Widget? leading;
  const StickyActionBar({super.key, required this.children, this.leading});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BillyColors.surface,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: BillyColors.border))),
        padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.md, BillySpace.gutter, BillySpace.md),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (leading != null) Expanded(child: leading!) else const Spacer(),
              const SizedBox(width: BillySpace.md),
              ...children.expand((w) => [w, const SizedBox(width: BillySpace.sm)]).toList()..removeLast(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름을 그대로 입력해야 지워지는 삭제 확인(한 번 눌러 실수로 지우지 않게).
Future<bool> confirmTypedDelete(BuildContext context, {required String title, required String name, required String detail}) async {
  final ctl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail, style: BillyText.body),
            const SizedBox(height: BillySpace.md),
            Text("확인을 위해 '$name' 을(를) 입력하세요", style: BillyText.captionStrong),
            const SizedBox(height: BillySpace.sm),
            TextField(controller: ctl, autofocus: true, onChanged: (_) => setState(() {})),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BillyColors.error),
            onPressed: ctl.text.trim() == name ? () => Navigator.pop(ctx, true) : null,
            child: const Text('삭제'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// 간단한 확인(되돌릴 수 있는 일).
Future<bool> confirmAction(BuildContext context, {required String title, required String message, String ok = '확인'}) async {
  final r = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: BillyText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// 내용 폭 제한(넓은 화면에서 끝까지 늘어나지 않게) + 좌우 여백.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double max;
  const ContentWidth({super.key, required this.child, this.max = BillySpace.maxContent});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
    );
  }
}

/// 오류 메시지 정리(Exception: 접두어 제거).
String errorText(Object e) => e.toString().replaceFirst('Exception: ', '').replaceFirst('TimeoutException after ', '응답이 없습니다: ');
