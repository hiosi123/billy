import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../services/file_saver.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';
import 'review_step.dart' show UnitBillCard;

/// 정산 4단계 — 확정 명세서와 입금. 엑셀은 확정본 그대로(다시 계산하지 않는다).
class StatementsStep extends StatefulWidget {
  final String month;
  final VoidCallback onGoReview;
  const StatementsStep({super.key, required this.month, required this.onGoReview});

  @override
  State<StatementsStep> createState() => _StatementsStepState();
}

class _StatementsStepState extends State<StatementsStep> {
  List<UnitBill>? _items;
  Object? _error;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant StatementsStep old) {
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
      final r = await p.api.getStatements(p.buildingId!, widget.month);
      if (!mounted || seq != _seq) return;
      setState(() {
        _items = r;
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

  Future<void> _excel() async {
    final p = context.read<AppProvider>();
    try {
      final bytes = await p.api.statementsXlsx(p.buildingId!, widget.month);
      final name = await saveXlsx(bytes, '명세서_${p.building?.buildingName ?? ''}_${widget.month}.xlsx');
      if (mounted) showSnack(context, '엑셀 명세서를 저장했습니다 ($name)');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _openPayment(UnitBill s) async {
    final updated = await showModalBottomSheet<UnitBill>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _PaymentSheet(bill: s),
    );
    if (updated != null && mounted) {
      setState(() => _items = [for (final x in _items ?? <UnitBill>[]) x.statementId == updated.statementId ? updated : x]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items ?? const <UnitBill>[];
    final total = items.fold(0.0, (s, x) => s + x.total);
    final paid = items.fold(0.0, (s, x) => s + (x.paidAmount > x.total ? x.total : x.paidAmount));
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
                      if (_loading && _items == null)
                        const LoadingView()
                      else if (_error != null)
                        ErrorBanner(message: '명세서를 불러오지 못했습니다: ${errorText(_error!)}', onRetry: _load)
                      else if (items.isEmpty)
                        EmptyView(
                          icon: Icons.receipt_long_outlined,
                          message: '${shortMonth(widget.month)}은 아직 확정 전입니다.\n검토에서 금액을 확인하고 확정하면 명세서가 나옵니다.',
                          action: FilledButton(onPressed: widget.onGoReview, child: const Text('검토하러 가기')),
                        )
                      else ...[
                        BillyCard(
                          // 칸 사이를 띄운다 — 폰에선 금액이 칸 끝까지 줄어 '10,495,847원0원'처럼 붙어 보였다
                          child: Row(children: [
                            _stat('청구', total, BillyColors.textPrimary),
                            const SizedBox(width: BillySpace.md),
                            _stat('입금', paid, BillyColors.success),
                            const SizedBox(width: BillySpace.md),
                            _stat('남은 금액', total - paid, total - paid > 0 ? BillyColors.error : BillyColors.textSecondary),
                          ]),
                        ),
                        SectionTitle('호실별 명세서', subtitle: '누르면 내역과 입금 기록 단추가 나옵니다'),
                        for (final s in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: BillySpace.sm),
                            child: UnitBillCard(
                              bill: s,
                              // 명세서에서는 사용량보다 입금 내역이 궁금하다
                              info: [
                                if (s.paidAmount > 0 && !s.paid) '${wonText(s.paidAmount)} 받음',
                                if (s.paidAt != null) '입금 ${s.paidAt}',
                                if ((s.memo ?? '').isNotEmpty) s.memo!,
                                if (s.paidAmount <= 0) '${num2(s.area)}m²',
                              ],
                              footer: SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () => _openPayment(s),
                                  icon: const Icon(Icons.payments_outlined, size: 18),
                                  label: Text(s.paidAmount > 0 || s.paidAt != null ? '입금 기록 고치기' : '입금 기록하기'),
                                ),
                              ),
                              trailing: InkWell(
                                onTap: () => _openPayment(s),
                                borderRadius: BorderRadius.circular(BillyRadius.sm),
                                child: Padding(
                                  // 손가락으로 누르기 쉽게 위아래를 넉넉히(칩만 누르면 28px 였다)
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                  child: StatusChip(
                                    s.paid ? '완납' : s.partlyPaid ? '일부' : '미납',
                                    tone: s.paid ? Tone.ok : s.partlyPaid ? Tone.warn : Tone.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isNotEmpty)
          StickyActionBar(
            leading: Text('명세서 ${items.length}장 · 입금 ${items.where((x) => x.paid).length}/${items.length}', style: BillyText.captionStrong),
            children: [
              SizedBox(height: 46, child: AsyncButton(label: '엑셀 명세서', icon: Icons.download_rounded, onPressed: _excel)),
            ],
          ),
      ],
    );
  }

  Widget _stat(String label, double v, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          Align(alignment: Alignment.centerLeft, child: MoneyText(v, size: 16, color: color)),
        ]),
      );
}

class _PaymentSheet extends StatefulWidget {
  final UnitBill bill;
  const _PaymentSheet({required this.bill});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _memo;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _amount = TextEditingController(text: b.paidAmount > 0 ? b.paidAmount.round().toString() : '');
    _memo = TextEditingController(text: b.memo ?? '');
    _date = b.paidAt != null ? DateTime.tryParse(b.paidAt!) : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  String? get _dateText => _date == null ? null : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';

  bool _busy = false;
  String? _error; // 창 안에 보인다 — 스낵바는 이 창 뒤에 깔려 안 보였다

  Future<void> _save({double? amount}) async {
    if (_busy) return;
    final p = context.read<AppProvider>();
    final text = _amount.text.replaceAll(',', '').replaceAll('원', '').trim();
    final v = amount ?? (text.isEmpty ? 0 : double.tryParse(text));
    // 예전엔 숫자가 아닌 글자를 넣고 저장하면 0원으로 저장돼 입금 기록이 지워졌다
    if (v == null || v < 0) {
      setState(() => _error = '입금액은 0 이상의 숫자로 넣어 주세요');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = (v > 0 && _date == null) ? DateTime.now() : _date;
      final updated = await p.api.recordPayment(p.buildingId!, widget.bill.statementId!,
          paidAmount: v,
          paidAt: v > 0 ? '${d!.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' : null,
          memo: _memo.text.trim());
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  Future<void> _clear() async {
    final ok = await confirmAction(context, title: '입금 기록을 지울까요?', message: '받은 금액·입금일·메모가 지워지고 미납으로 돌아갑니다.', ok: '지우기');
    if (ok && mounted) await _save(amount: 0);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bill;
    // 작은 폰 + 키보드면 창이 화면보다 길다 — 스크롤되게, 아래 시스템 단추에 가리지 않게
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${b.title} 입금', style: BillyText.title),
          const SizedBox(height: BillySpace.xs),
          Row(children: [
            Text('청구 ', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            MoneyText(b.total, size: 14),
          ]),
          const SizedBox(height: BillySpace.lg),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            style: BillyText.money(16, weight: FontWeight.w400),
            decoration: InputDecoration(labelText: '입금액', suffixText: '원', helperText: '일부만 받았으면 받은 금액만 넣으세요'),
          ),
          const SizedBox(height: BillySpace.md),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                useRootNavigator: true,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _date = d);
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(_dateText == null ? '입금일 고르기(비우면 오늘)' : '입금일 $_dateText'),
          ),
          const SizedBox(height: BillySpace.md),
          TextField(controller: _memo, decoration: const InputDecoration(labelText: '메모(선택)')),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: BillySpace.md),
              child: Text(keepAll(_error!), style: BillyText.caption.copyWith(color: BillyColors.error)),
            ),
          const SizedBox(height: BillySpace.lg),
          // 폰 폭에서 단추 셋이 한 줄이면 '입금 취소'가 두 줄로 깨졌다 — 지우기는 받은 기록이 있을 때만 아래 줄에
          Row(children: [
            Expanded(
              child: SizedBox(height: 46, child: OutlinedButton(onPressed: _busy ? null : () => _save(amount: b.total), child: const Text('완납'))),
            ),
            const SizedBox(width: BillySpace.sm),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : () => _save(),
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: BillyColors.onDark))
                      : const Text('저장'),
                ),
              ),
            ),
          ]),
          if (b.paidAmount > 0 || b.paidAt != null) ...[
            const SizedBox(height: BillySpace.xs),
            TextButton(
              onPressed: _busy ? null : _clear,
              style: TextButton.styleFrom(foregroundColor: BillyColors.error),
              child: const Text('입금 기록 지우기'),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
