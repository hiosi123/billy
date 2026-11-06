import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import 'readings_step.dart';
import 'invoice_step.dart';
import 'review_step.dart';
import 'statements_step.dart';

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
    void go(String m, int i) {
      if (m != p.workingMonth) context.read<AppProvider>().setWorkingMonth(m);
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
          preferredSize: const Size.fromHeight(52),
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
      height: 52,
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
              child: Text(
                compact ? '${i + 1} ${s.$3}' : '${i + 1}. ${s.$2}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BillyText.captionStrong.copyWith(color: selected ? BillyColors.onDark : BillyColors.textSecondary),
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
