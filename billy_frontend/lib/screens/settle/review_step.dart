import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 정산 3단계 — 검토·확정. 서버가 요금표대로 계산한 호실별 금액(쓰기 없음)을 보고 확정한다.
/// 확정하면 그 금액이 명세서로 저장된다(앱에서 보는 금액 = 명세서 금액).
class ReviewStep extends StatefulWidget {
  final String month;
  final VoidCallback onIssued;
  const ReviewStep({super.key, required this.month, required this.onIssued});

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  PreviewV2? _preview;
  Object? _error;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ReviewStep old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _load();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await p.api.previewMonth(p.buildingId!, widget.month);
      if (!mounted || seq != _seq) return;
      setState(() {
        _preview = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool _issuing = false;

  /// 확정할 수 있는지 — 다시 계산 중이거나 계산이 실패했으면 화면의 옛 금액으로 확정하지 않게 막는다.
  bool get _canIssue {
    final pv = _preview;
    return !_issuing && !_loading && _error == null && pv != null && !pv.hasErrors && pv.units.isNotEmpty;
  }

  Future<void> _issue() async {
    final pv = _preview;
    if (!_canIssue || pv == null) return;
    final again = pv.issuedCount > 0;
    final ok = await confirmAction(
      context,
      title: again ? '다시 확정할까요?' : '${shortMonth(widget.month)}을 확정할까요?',
      message: again
          ? '이미 확정된 달입니다. 다시 확정하면 명세서 금액이 지금 계산으로 바뀝니다(입금 기록은 남습니다).'
          : '호실 ${pv.units.length}곳, 합계 ${wonText(pv.total)}을 명세서로 저장합니다. 나중에 다시 확정할 수 있습니다.',
      ok: again ? '다시 확정' : '확정',
    );
    if (!ok || !mounted) return;
    final p = context.read<AppProvider>();
    setState(() => _issuing = true);
    try {
      await p.api.issueMonth(p.buildingId!, widget.month);
      if (!mounted) return;
      showSnack(context, '${shortMonth(widget.month)} 명세서 ${pv.units.length}장을 확정했습니다');
      // 정산할 달을 다음 달로(이번 달 화면·정산 탭 기본값)
      final next = MonthStepper.shift(widget.month, 1);
      if (next.compareTo(currentChargeMonth()) <= 0 && p.workingMonth.compareTo(next) < 0) p.setWorkingMonth(next);
      widget.onIssued();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pv = _preview;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.md, BillySpace.gutter, BillySpace.xl),
              children: [
                ContentWidth(
                  max: 900,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading && pv == null)
                        const LoadingView()
                      else if (_error != null)
                        ErrorBanner(message: '계산하지 못했습니다: ${errorText(_error!)}', onRetry: _load)
                      else if (pv != null) ...[
                        if (pv.issuedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: BillySpace.sm),
                            child: StatusChip('이미 확정됨 · 명세서 ${pv.issuedCount}장', tone: Tone.ok, icon: Icons.check_circle_rounded),
                          ),
                        IssueList(pv.issues),
                        if (pv.units.isNotEmpty) ...[
                          _Summary(preview: pv),
                          SectionTitle('호실별 금액', subtitle: pv.planSource == 'default' ? '요금표: 기본(${_presetName(pv.preset)}) — 설정에서 바꿀 수 있습니다' : null),
                          for (final u in pv.units)
                            Padding(
                              padding: const EdgeInsets.only(bottom: BillySpace.sm),
                              child: UnitBillCard(bill: u, lastTotal: pv.lastTotals[u.unitNumber]),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        StickyActionBar(
          leading: pv == null || pv.units.isEmpty
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('합계', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
                    Align(alignment: Alignment.centerLeft, child: MoneyText(pv.total, size: 18)),
                  ],
                ),
          children: [
            // 다시 계산 중이면 단추 자리에 돌아가는 표시
            _loading && pv != null
                ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.2)))
                : IconButton(tooltip: '다시 계산', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _canIssue ? _issue : null,
                icon: _issuing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: BillyColors.onDark))
                    : const Icon(Icons.verified_rounded),
                label: Text(pv != null && pv.issuedCount > 0 ? '다시 확정' : '확정하기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 프리셋 이름(화면 표기) — 서버 id 를 그대로 보이지 않는다.
String _presetName(String? id) => switch (id) {
      'legacy-v1' => '기존 방식',
      'basic-v1' => '기본 상가형',
      'blank' => '빈 요금표',
      _ => id ?? '',
    };

class _Summary extends StatelessWidget {
  final PreviewV2 preview;
  const _Summary({required this.preview});

  @override
  Widget build(BuildContext context) {
    final groups = <String, (String, double)>{};
    for (final u in preview.units) {
      for (final g in u.groups) {
        final cur = groups[g.group];
        groups[g.group] = (g.label, (cur?.$2 ?? 0) + g.amount);
      }
    }
    final last = preview.lastTotals.isEmpty ? null : preview.lastTotals.values.fold(0.0, (s, v) => s + v);
    return BillyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('${shortMonth(preview.month)} 합계', style: BillyText.captionStrong.copyWith(color: BillyColors.textSecondary))),
            Text('검침 ${preview.readingsEntered}/${preview.readingsTotal}', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          ]),
          const SizedBox(height: BillySpace.xs),
          Align(alignment: Alignment.centerLeft, child: MoneyText(preview.total, size: 26)),
          if (last != null) ...[
            const SizedBox(height: 2),
            Text('지난달 ${wonText(last)} · ${preview.total - last >= 0 ? '+' : ''}${wonText(preview.total - last)}',
                style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          ],
          const SizedBox(height: BillySpace.md),
          Wrap(
            spacing: BillySpace.sm,
            runSpacing: BillySpace.sm,
            children: [
              for (final e in groups.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: BillySpace.md, vertical: BillySpace.sm),
                  decoration: BoxDecoration(color: BillyColors.groupSoft(e.key), borderRadius: BorderRadius.circular(BillyRadius.md)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.$1, style: BillyText.tiny.copyWith(color: BillyColors.group(e.key))),
                    MoneyText(e.value.$2, size: 14),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 호실 하나의 금액 카드 — 펼치면 묶음별 항목·소계. 미리보기·확정 명세서에서 같이 쓴다.
class UnitBillCard extends StatelessWidget {
  final UnitBill bill;
  final double? lastTotal;
  final Widget? trailing;
  final Widget? footer; // 펼친 내역 맨 아래(명세서: 입금 기록 단추)
  final List<String>? info; // 이름 아래 줄. 없으면 면적·사용량
  const UnitBillCard({super.key, required this.bill, this.lastTotal, this.trailing, this.footer, this.info});

  @override
  Widget build(BuildContext context) {
    final delta = lastTotal == null ? null : bill.total - lastTotal!;
    return Material(
      color: BillyColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.lg), side: const BorderSide(color: BillyColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: BillyColors.surface),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: BillySpace.lg, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(BillySpace.lg, 0, BillySpace.lg, BillySpace.lg),
          title: Text(bill.title, style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: DotLine(info ??
              [
                '${num2(bill.area)}m²',
                if (bill.usageElectricity > 0) '전기 ${num2(bill.usageElectricity)}kWh',
                if (bill.usageWater > 0) '수도 ${num2(bill.usageWater)}m³',
                if (delta != null) '지난달보다 ${delta >= 0 ? '+' : ''}${wonText(delta)}',
              ]),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 108, child: MoneyText(bill.total, size: 15)),
            if (trailing != null) ...[const SizedBox(width: BillySpace.sm), trailing!],
          ]),
          children: [
            for (final g in bill.groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: BillySpace.sm, bottom: BillySpace.xs),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: BillyColors.group(g.group), shape: BoxShape.circle)),
                  const SizedBox(width: BillySpace.sm),
                  Expanded(child: Text(g.label, style: BillyText.captionStrong.copyWith(color: BillyColors.group(g.group)))),
                  SizedBox(width: 110, child: MoneyText(g.amount, size: 13.5)),
                ]),
              ),
              for (final l in bill.lines.where((l) => l.group == g.group))
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
                  child: Row(children: [
                    Expanded(
                      child: Text(l.hidden ? '${l.label} (명세서에 안 보임)' : l.label,
                          style: BillyText.caption.copyWith(color: l.hidden ? BillyColors.textHint : BillyColors.textPrimary)),
                    ),
                    SizedBox(width: 110, child: MoneyText(l.amount, size: 13, weight: FontWeight.w400, color: l.hidden ? BillyColors.textHint : BillyColors.textPrimary)),
                  ]),
                ),
            ],
            if (footer != null) Padding(padding: const EdgeInsets.only(top: BillySpace.md), child: footer!),
          ],
        ),
      ),
    );
  }
}
