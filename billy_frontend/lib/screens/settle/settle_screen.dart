import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'readings_step.dart';
import 'invoice_step.dart';
import 'review_step.dart';
import 'statements_step.dart';

/// 정산 단계의 '저장 안 한 입력' — 검침·고지서 단계가 맡겨 두고, 단계·달·아래 탭을 옮기기 전에 묻는다.
/// (예전엔 검침 11곳을 넣고 '2 고지서'를 누르면 말없이 다 사라졌다.)
class SettleDraft {
  SettleDraft._();
  static Object? _owner;
  static String? Function()? _pending;
  static Future<bool> Function()? _save;
  static void Function()? _discard;

  /// [pending] 저장 안 한 것의 이름(없으면 null) · [save] 저장하고 남은 게 없으면 true · [discard] 입력을 저장된 값으로 되돌린다.
  static void claim(Object owner,
      {required String? Function() pending, required Future<bool> Function() save, required void Function() discard}) {
    _owner = owner;
    _pending = pending;
    _save = save;
    _discard = discard;
  }

  static void release(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _pending = null;
    _save = null;
    _discard = null;
  }

  static String? get pending => _pending?.call();
}

/// 저장 안 한 입력이 있으면 묻는다(저장하고 이동 · 버리기 · 취소). 옮겨도 되면 true.
Future<bool> confirmLeaveSettle(BuildContext context) async {
  // 세션이 끝나 로그인으로 보낼 때는 묻지 않는다(묻는 사이 토큰이 없어 저장도 못 한다)
  if (!AuthService.isLoggedIn) return true;
  final what = SettleDraft.pending;
  if (what == null) return true;
  final r = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: const Text('저장하지 않은 입력이 있습니다'),
      content: Text(keepAll('$what을 아직 저장하지 않았습니다. 그냥 옮기면 사라집니다.'), style: BillyText.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'discard'),
          style: TextButton.styleFrom(foregroundColor: BillyColors.error),
          child: const Text('버리기'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('저장하고 이동')),
      ],
    ),
  );
  if (r == 'discard') {
    SettleDraft._discard?.call();
    return true;
  }
  if (r == 'save') return await SettleDraft._save?.call() ?? true;
  return false;
}

/// 정산 — 한 달을 4단계로: 검침 → 고지서 → 검토·확정 → 명세서·입금. 달·단계는 주소에 있다.
class SettleScreen extends StatelessWidget {
  final String month;
  final String? step;
  const SettleScreen({super.key, required this.month, this.step});

  static const steps = [
    ('readings', '검침', '검침'),
    ('invoice', '고지서', '고지서'),
    ('review', '검토·확정', '확정'),
    ('statements', '명세서·입금', '명세서'),
  ];

  int get _index {
    final i = steps.indexWhere((s) => s.$1 == step);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final bid = p.buildingId;
    Future<void> go(String m, int i) async {
      if (m == month && i == _index) return;
      if (!await confirmLeaveSettle(context) || !context.mounted) return;
      // 달을 옮길 때만 '정산할 달'을 따라 바꾼다 — 단계만 옮길 때 바꾸면 확정 직후 다음 달로 넘긴 것이 되돌아갔다
      if (m != month && m != p.workingMonth) context.read<AppProvider>().setWorkingMonth(m);
      context.go('/b/$bid/settle/$m?step=${steps[i].$1}');
    }

    final valid = RegExp(r'^\d{6}$').hasMatch(month);
    return Scaffold(
      appBar: buildingAppBar(
        context,
        valid ? '${shortMonth(month)} 정산' : '정산',
        actions: [
          IconButton(tooltip: '이전 달', onPressed: () => go(MonthStepper.shift(month, -1), _index), icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(tooltip: '다음 달', onPressed: () => go(MonthStepper.shift(month, 1), _index), icon: const Icon(Icons.chevron_right_rounded)),
          const SizedBox(width: BillySpace.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StepTabs(index: _index, onTap: (i) => go(month, i)),
        ),
      ),
      body: !valid
          ? const Center(child: Text('달이 올바르지 않습니다'))
          : switch (_index) {
              0 => ReadingsStep(key: ValueKey('r$month'), month: month, onNext: () => go(month, 1)),
              1 => InvoiceStep(key: ValueKey('i$month'), month: month, onNext: () => go(month, 2)),
              2 => ReviewStep(key: ValueKey('v$month'), month: month, onIssued: () => go(month, 3)),
              _ => StatementsStep(key: ValueKey('s$month'), month: month, onGoReview: () => go(month, 2)),
            },
    );
  }
}

class _StepTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _StepTabs({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BillyColors.border))),
      padding: const EdgeInsets.symmetric(horizontal: BillySpace.gutter, vertical: BillySpace.sm),
      child: LayoutBuilder(builder: (context, c) {
        // 폰에서는 네 단계가 한 줄에 다 보이게 짧은 이름으로 나눠 채운다
        final compact = c.maxWidth < 520;
        Widget pill(int i) {
          final selected = i == index;
          final s = SettleScreen.steps[i];
          return InkWell(
            borderRadius: BorderRadius.circular(BillyRadius.xl),
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: BillySpace.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? BillyColors.primary : BillyColors.surfaceAlt,
                borderRadius: BorderRadius.circular(BillyRadius.xl),
                border: Border.all(color: selected ? BillyColors.primary : BillyColors.border),
              ),
              // 큰 글자에서도 '4 명세…'로 잘리지 않게 줄여서 보인다
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  compact ? '${i + 1} ${s.$3}' : '${i + 1}. ${s.$2}',
                  maxLines: 1,
                  style: BillyText.captionStrong.copyWith(color: selected ? BillyColors.onDark : BillyColors.textSecondary),
                ),
              ),
            ),
          );
        }

        if (compact) {
          return Row(children: [
            for (var i = 0; i < SettleScreen.steps.length; i++) ...[
              if (i > 0) const SizedBox(width: BillySpace.xs),
              Expanded(child: pill(i)),
            ],
          ]);
        }
        return Row(children: [
          for (var i = 0; i < SettleScreen.steps.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: BillyColors.textHint),
              ),
            pill(i),
          ],
        ]);
      }),
    );
  }
}
