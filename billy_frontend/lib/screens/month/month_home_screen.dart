import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 이번 달 — 한 달 정산이 어디까지 왔는지(검침 → 고지서 → 확정 → 명세서·입금)와 최근 달 현황.
class MonthHomeScreen extends StatefulWidget {
  final String? month;
  const MonthHomeScreen({super.key, this.month});

  @override
  State<MonthHomeScreen> createState() => _MonthHomeScreenState();
}

class _MonthHomeScreenState extends State<MonthHomeScreen> {
  List<MonthStatus>? _months;
  int _meters = 0;
  Object? _error;
  bool _loading = true;

  String get _month {
    final m = widget.month;
    if (m != null && RegExp(r'^\d{6}$').hasMatch(m)) return m;
    return context.read<AppProvider>().workingMonth;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant MonthHomeScreen old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _load();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final bid = p.buildingId;
    if (bid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = currentChargeMonth();
      // 12달 창에 이 달이 들어오게 — 1년 넘게 지난 달은 그 달부터 본다(예전엔 늘 '아직 확정 전'으로 보였다)
      final until = _month.compareTo(current) > 0
          ? _month
          : _month.compareTo(MonthStepper.shift(current, -11)) < 0
              ? MonthStepper.shift(_month, 11)
              : current;
      final r = await p.api.getOverview(bid, count: 12, until: until);
      if (!mounted) return;
      setState(() {
        _months = r.months;
        _meters = r.meters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  MonthStatus? _status(String m) {
    for (final s in _months ?? const <MonthStatus>[]) {
      if (s.month == m) return s;
    }
    return null;
  }

  double? _totalOf(MonthStatus? s) => s == null ? null : (s.statements?.total ?? s.legacyTotal);

  void _goStep(String step) {
    final bid = context.read<AppProvider>().buildingId;
    context.go('/b/$bid/settle/$_month?step=$step');
  }

  @override
  Widget build(BuildContext context) {
    final bid = context.watch<AppProvider>().buildingId;
    final month = _month;
    return Scaffold(
      appBar: buildingAppBar(context, '이번 달', actions: [
        IconButton(tooltip: '새로고침', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, BillySpace.xxxl),
          children: [
            ContentWidth(
              max: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MonthStepper(month: month, onChanged: (m) => context.go('/b/$bid/home?m=$m')),
                  ),
                  const SizedBox(height: BillySpace.md),
                  if (_loading && _months == null)
                    const LoadingView()
                  else if (_error != null)
                    ErrorBanner(message: '현황을 불러오지 못했습니다: ${errorText(_error!)}', onRetry: _load)
                  else ...[
                    _Hero(month: month, status: _status(month), lastTotal: _totalOf(_status(MonthStepper.shift(month, -1)))),
                    const SectionTitle('할 일', subtitle: '순서대로 하면 명세서까지 끝납니다'),
                    _Steps(status: _status(month), meters: _meters, onStep: _goStep),
                    const SectionTitle('최근 달'),
                    BillyCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // 보고 있는 달보다 뒤인데 아무것도 안 한 달은 아직 할 차례가 아니라 뺀다
                          for (final s in (_months ?? const <MonthStatus>[])
                              .where((s) => s.month != month && (s.month.compareTo(month) < 0 || s.readingsEntered > 0 || s.inputsSaved || s.issued))
                              .take(6)) ...[
                            _MonthRow(status: s, onTap: () => context.go('/b/$bid/home?m=${s.month}')),
                            const Divider(height: 1),
                          ],
                        ]..removeLastIfDivider(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on List<Widget> {
  List<Widget> removeLastIfDivider() {
    if (isNotEmpty && last is Divider) removeLast();
    return this;
  }
}

class _Hero extends StatelessWidget {
  final String month;
  final MonthStatus? status;
  final double? lastTotal;
  const _Hero({required this.month, required this.status, required this.lastTotal});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final total = s?.statements?.total ?? s?.legacyTotal;
    final invoiceMonth = int.parse(MonthStepper.shift(month, 1).substring(4, 6));
    final delta = (total != null && lastTotal != null) ? total - lastTotal! : null;
    return Container(
      padding: const EdgeInsets.all(BillySpace.xl),
      decoration: BoxDecoration(gradient: BillyColors.headerGradient, borderRadius: BorderRadius.circular(BillyRadius.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${shortMonth(month)} 관리비 · $invoiceMonth월 고지', style: BillyText.caption.copyWith(color: BillyColors.onDarkMuted)),
          const SizedBox(height: BillySpace.sm),
          if (total != null)
            Align(alignment: Alignment.centerLeft, child: MoneyText(total, size: 30, color: BillyColors.onDark))
          else
            Text('아직 확정 전', style: BillyText.headline.copyWith(color: BillyColors.onDark)),
          const SizedBox(height: BillySpace.sm),
          Wrap(
            spacing: BillySpace.sm,
            runSpacing: BillySpace.xs,
            children: [
              if (s?.issued == true) _pill('명세서 ${s!.statements!.count}장'),
              if (s?.statements == null && s?.legacyTotal != null) _pill('예전 앱에서 저장'),
              if (delta != null) _pill('지난달보다 ${delta >= 0 ? '+' : ''}${wonText(delta)}'),
              if (s?.issued == true) _pill('입금 ${s!.statements!.paidCount}/${s.statements!.count}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: BillyColors.onDarkFaint, borderRadius: BorderRadius.circular(BillyRadius.xl)),
        child: Text(t, style: BillyText.tiny.copyWith(color: BillyColors.onDark)),
      );
}

class _Steps extends StatelessWidget {
  final MonthStatus? status;
  final int meters;
  final ValueChanged<String> onStep;
  const _Steps({required this.status, required this.meters, required this.onStep});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final entered = s?.readingsEntered ?? 0;
    final total = s?.readingsTotal ?? meters;
    final readingsDone = total > 0 && entered >= total;
    final inputs = s?.inputsSaved ?? false;
    final issued = s?.issued ?? false;
    final paid = s?.allPaid ?? false;
    final steps = [
      ('readings', Icons.speed_rounded, '검침', readingsDone ? '$entered/$total 계량기 입력됨' : '$entered/$total 계량기 — ${total - entered}개 남음', readingsDone ? Tone.ok : Tone.warn),
      ('invoice', Icons.description_outlined, '고지서 금액', inputs ? '입력됨' : '전기·수도 고지서 금액을 넣어 주세요', inputs ? Tone.ok : Tone.warn),
      (
        'review',
        Icons.fact_check_outlined,
        '검토·확정',
        issued ? '확정됨${_date(s!.statements!.issuedAt)}' : '호실별 금액을 확인하고 확정',
        issued ? Tone.ok : Tone.info
      ),
      (
        'statements',
        Icons.receipt_long_outlined,
        '명세서·입금',
        issued ? '입금 ${s!.statements!.paidCount}/${s.statements!.count} · ${wonText(s.statements!.paidAmount)} 받음' : '확정하면 명세서가 나옵니다',
        issued ? (paid ? Tone.ok : Tone.warn) : Tone.neutral
      ),
    ];
    // 확정한 달은 명세서로 — 빈 계량기가 있어도 확정은 되니 검침으로 돌려보내지 않는다
    final next = issued ? 'statements' : !readingsDone ? 'readings' : !inputs ? 'invoice' : 'review';
    return BillyCard(
      padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            ListTile(
              onTap: () => onStep(steps[i].$1),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: toneSoft(steps[i].$5),
                child: Icon(steps[i].$5 == Tone.ok ? Icons.check_rounded : steps[i].$2, size: 18, color: toneColor(steps[i].$5)),
              ),
              title: Text('${i + 1}. ${steps[i].$3}', style: BillyText.bodyStrong),
              subtitle: Text(keepAll(steps[i].$4), style: BillyText.caption.copyWith(color: BillyColors.textSecondary), maxLines: 2),
              trailing: const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(BillySpace.lg, BillySpace.xs, BillySpace.lg, BillySpace.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onStep(next),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(issued && paid ? '명세서 보기' : '이어서 하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : ' (${d.month}/${d.day})';
  }
}

class _MonthRow extends StatelessWidget {
  final MonthStatus status;
  final VoidCallback onTap;
  const _MonthRow({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = status;
    final total = s.statements?.total ?? s.legacyTotal;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BillySpace.lg, vertical: BillySpace.md),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(shortMonth(s.month), style: BillyText.bodyStrong)),
            Expanded(
              child: Wrap(
                spacing: BillySpace.xs,
                runSpacing: BillySpace.xs,
                children: [
                  StatusChip('검침 ${s.readingsEntered}/${s.readingsTotal}', tone: s.readingsDone ? Tone.ok : (s.readingsEntered > 0 ? Tone.warn : Tone.neutral)),
                  if (s.issued)
                    StatusChip(s.allPaid ? '입금 완료' : '입금 ${s.statements!.paidCount}/${s.statements!.count}', tone: s.allPaid ? Tone.ok : Tone.warn)
                  else if (s.legacyTotal != null)
                    const StatusChip('예전 앱 저장', tone: Tone.info)
                  else
                    const StatusChip('미확정'),
                ],
              ),
            ),
            if (total != null) SizedBox(width: 110, child: MoneyText(total, size: 14)),
          ],
        ),
      ),
    );
  }
}
