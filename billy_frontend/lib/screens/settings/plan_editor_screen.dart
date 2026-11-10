import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../models/plan.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 저장하지 않은 변경이 있는지 — 이 화면을 떠날 때(뒤로·아래 탭·주소) 라우터가 묻는 데 쓴다.
final planEditorDirty = ValueNotifier<bool>(false);

/// 관리비 항목(요금표) — 우리 건물 방식대로 항목·나누는 방식·요율을 정한다.
/// 저장할 때 '몇 월부터' 적용할지 고른다(이미 확정한 달의 명세서는 그대로).
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  PlanDef? _plan;
  String? _month; // 이 달에 쓰이는 요금표를 보고 있다
  String _source = '';
  String? _effectiveFrom;
  List<String> _versions = []; // 저장된 버전의 적용 시작월(최근 것부터)
  Object? _error;
  bool _dirtyValue = false;
  bool get _dirty => _dirtyValue;
  set _dirty(bool v) => planEditorDirty.value = _dirtyValue = v;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    planEditorDirty.value = false;
    super.dispose();
  }

  /// [month]에 쓰이는 요금표를 연다. 처음 열 때는 앞으로 쓰일 가장 최근 버전을 보여준다.
  Future<void> _load([String? month]) async {
    final p = context.read<AppProvider>();
    setState(() => _error = null);
    try {
      var m = month ?? _month ?? p.workingMonth;
      var r = await p.api.getPlan(p.buildingId!, m);
      if (month == null && _month == null && r.versions.isNotEmpty && r.versions.first.compareTo(m) > 0) {
        m = r.versions.first;
        r = await p.api.getPlan(p.buildingId!, m);
      }
      if (!mounted) return;
      setState(() {
        _month = m;
        _plan = r.plan;
        _source = r.source;
        _effectiveFrom = r.effectiveFrom;
        _versions = r.versions;
        _dirty = false;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _changed(VoidCallback f) => setState(() {
        f();
        _dirty = true;
      });

  Future<void> _openVersion(String month) async {
    if (_dirty) {
      final ok = await confirmAction(context, title: '저장하지 않은 변경이 있습니다', message: '다른 버전을 열면 지금 고친 내용은 사라집니다.', ok: '버리고 열기');
      if (!ok || !mounted) return;
    }
    setState(() {
      _plan = null;
      _month = month; // 다시 시도해도 고른 버전을 연다
      _dirty = false; // 버리기로 했다
    });
    await _load(month);
  }

  Future<void> _fromPreset(String id, String name) async {
    final ok = await confirmAction(context,
        title: "'$name'으로 다시 시작할까요?", message: '지금 화면의 항목이 프리셋으로 바뀝니다. 저장하기 전까지는 실제 계산에 쓰이지 않습니다.', ok: '바꾸기');
    if (!ok || !mounted) return;
    final p = context.read<AppProvider>();
    try {
      final plan = await p.api.getPresetPlan(p.buildingId!, id);
      if (!mounted) return; // 그새 화면을 나갔으면 '고침' 표시를 되살리지 않는다
      _changed(() => _plan = plan);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  // ── 항목 편집 ──
  Future<void> _editItem({PlanItem? item, String? group}) async {
    final plan = _plan!;
    final index = item == null ? null : plan.items.indexOf(item);
    final draft = item?.copy() ??
        PlanItem(code: plan.newCode('item'), label: '', group: group ?? plan.groups.first.code, method: ChargeMethod.areaSplit, amount: 0);
    final before = index == null ? plan.items : plan.items.sublist(0, index);
    final result = await showModalBottomSheet<(PlanItem?, bool)>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _ItemEditor(item: draft, plan: plan, before: before, isNew: item == null),
    );
    if (result == null) return;
    final (edited, deleted) = result;
    if (deleted && index != null) {
      final code = plan.items[index].code;
      final users = plan.items.where((x) => x.code != code && (x.refs.contains(code) || x.of == code)).map((x) => "'${x.label}'").toList();
      if (users.isNotEmpty) {
        if (mounted) showSnack(context, '${users.join('·')} 항목이 이 항목을 쓰고 있어 지울 수 없습니다. 먼저 그 항목에서 빼 주세요', error: true);
        return;
      }
    }
    // 열어 보기만 하고 '적용'을 누르면 바뀐 게 없다 — '저장 안 한 변경'으로 표시하지 않는다
    if (!deleted && edited != null && index != null && jsonEncode(edited.toJson()) == jsonEncode(plan.items[index].toJson())) return;
    _changed(() {
      if (deleted && index != null) {
        plan.items.removeAt(index);
      } else if (edited != null) {
        if (index != null) {
          plan.items[index] = edited;
        } else {
          // 맨 끝에 넣는다 — 화면은 묶음별로 보여 같은 묶음의 마지막에 보이고, 참조(%·남는 금액)할 항목은 모두 앞에 있게 된다
          plan.items.add(edited);
        }
      }
    });
  }

  /// 계산 순서 문제 — %·남는 금액 항목은 쓰는 항목보다 아래에 있어야 한다(위에서부터 계산).
  String? _orderProblem(List<PlanItem> items) {
    for (var i = 0; i < items.length; i++) {
      final x = items[i];
      for (final r in [...x.refs, if (x.of != null) x.of!]) {
        final j = items.indexWhere((y) => y.code == r);
        if (j > i) return "'${x.label}'은(는) '${items[j].label}'을(를) 쓰므로 그보다 아래에 있어야 합니다";
      }
    }
    return null;
  }

  void _move(PlanItem item, int dir) {
    final items = _plan!.items;
    final i = items.indexOf(item);
    var j = i + dir;
    while (j >= 0 && j < items.length && items[j].group != item.group) {
      j += dir;
    }
    if (j < 0 || j >= items.length) return;
    final moved = [...items];
    moved[i] = items[j];
    moved[j] = item;
    final problem = _orderProblem(moved);
    if (problem != null) {
      showSnack(context, problem, error: true);
      return;
    }
    _changed(() {
      items[i] = items[j];
      items[j] = item;
    });
  }

  Future<void> _renameGroup(PlanGroup g) async {
    final ctl = TextEditingController(text: g.label);
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('묶음 이름'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          inputFormatters: [LengthLimitingTextInputFormatter(40)], // 서버가 40자에서 자른다
          decoration: const InputDecoration(helperText: '명세서의 소계 이름(예: 관리비, 전기료)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('확인')),
        ],
      ),
    );
    ctl.dispose();
    if (name != null && name.isNotEmpty && name != g.label) _changed(() => g.label = name);
  }

  void _addGroup() {
    final plan = _plan!;
    if (plan.groups.length >= 12) {
      showSnack(context, '묶음은 12개까지 만들 수 있습니다', error: true);
      return;
    }
    var i = plan.groups.length + 1;
    var code = 'group$i';
    while (plan.groups.any((g) => g.code == code)) {
      code = 'group${++i}';
    }
    _changed(() => plan.groups.add(PlanGroup(code, '새 묶음')));
  }

  void _removeGroup(PlanGroup g) {
    if (_plan!.items.any((x) => x.group == g.code)) {
      showSnack(context, '항목이 있는 묶음은 지울 수 없습니다. 항목을 먼저 옮기거나 지워주세요', error: true);
      return;
    }
    _changed(() => _plan!.groups.remove(g));
  }

  // ── 미리보기·저장 ──
  Future<void> _preview() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _PreviewSheet(plan: _plan!),
    );
  }

  /// 저장하려는 달이 이미 저장된 버전과 겹치면 알려 준다.
  String? _saveNote(String month) {
    final later = _versions.where((v) => v.compareTo(month) > 0).toList()..sort();
    // 옛 버전(예: 3월분부터)을 열어 고친 뒤 더 뒤의 달로 저장하면, 그 사이 버전(9월분부터) 대신 이 내용이 쓰인다 — 말없이 바뀌지 않게
    final viewing = _source == 'saved' ? _effectiveFrom : null;
    final skipped = viewing == null
        ? const <String>[]
        : (_versions.where((v) => v.compareTo(viewing) > 0 && v.compareTo(month) <= 0 && v != month).toList()..sort());
    final notes = [
      if (skipped.isNotEmpty) '지금 고친 것은 ${monthLabel(viewing!)}부터 쓰던 옛 요금표입니다 — ${monthLabel(skipped.last)}부터 쓰던 요금표 대신 이 내용이 쓰입니다.',
      if (_versions.contains(month)) '${monthLabel(month)}부터 쓰던 요금표를 이 내용으로 바꿉니다.',
      if (later.isNotEmpty) '${monthLabel(later.first)}부터는 따로 저장한 요금표가 있어 그쪽을 씁니다.',
    ];
    return notes.isEmpty ? null : notes.join(' ');
  }

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    // 정산할 달보다 뒤의 버전을 보고 있으면 그 버전을 고치는 것으로 본다
    final viewing = _source == 'saved' ? _effectiveFrom : null;
    var month = viewing != null && viewing.compareTo(p.workingMonth) > 0 ? viewing : p.workingMonth;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final note = _saveNote(month);
        return AlertDialog(
          title: const Text('언제부터 적용할까요?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            MonthStepper(month: month, dense: true, onChanged: (m) => setD(() => month = m)),
            const SizedBox(height: BillySpace.md),
            Text(keepAll('${monthLabel(month)} 정산부터 이 요금표로 계산합니다. 이미 확정한 달의 명세서는 그대로입니다(다시 확정하면 바뀝니다).'),
                style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            if (note != null) ...[
              const SizedBox(height: BillySpace.sm),
              Text(note, style: BillyText.caption.copyWith(color: BillyColors.warning)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
          ],
        );
      }),
    );
    if (ok != true || !mounted) return;
    try {
      await p.api.savePlan(p.buildingId!, month, _plan!);
      if (!mounted) return;
      showSnack(context, '${monthLabel(month)}부터 새 요금표를 씁니다');
      await _load(month);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: buildingAppBar(context, '관리비 항목', back: '/b/${context.read<AppProvider>().buildingId}/settings', actions: [
        PopupMenuButton<String>(
          tooltip: '프리셋',
          icon: const Icon(Icons.auto_fix_high_rounded),
          onSelected: (v) {
            final (id, name) = switch (v) { 'legacy-v1' => ('legacy-v1', '기존 방식'), 'basic-v1' => ('basic-v1', '기본 상가형'), _ => ('blank', '빈 요금표') };
            _fromPreset(id, name);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'legacy-v1', child: Text('기존 방식으로 다시 시작')),
            PopupMenuItem(value: 'basic-v1', child: Text('기본 상가형으로 다시 시작')),
            PopupMenuItem(value: 'blank', child: Text('빈 요금표로 다시 시작')),
          ],
        ),
      ]),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(BillySpace.gutter), child: ErrorBanner(message: '요금표를 불러오지 못했습니다: ${errorText(_error!)}', onRetry: _load))
          : plan == null
              ? const LoadingView()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, BillySpace.xl),
                        children: [
                          ContentWidth(
                            max: 820,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _infoCard(plan),
                                for (final g in plan.groups) ...[
                                  SectionTitle(
                                    g.label,
                                    subtitle: '명세서 소계 묶음',
                                    action: Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(tooltip: '이름 바꾸기', onPressed: () => _renameGroup(g), icon: const Icon(Icons.edit_outlined, size: 18)),
                                      if (plan.items.every((x) => x.group != g.code))
                                        IconButton(tooltip: '묶음 지우기', onPressed: () => _removeGroup(g), icon: const Icon(Icons.delete_outline_rounded, size: 18)),
                                      TextButton.icon(onPressed: () => _editItem(group: g.code), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('항목')),
                                    ]),
                                  ),
                                  BillyCard(
                                    padding: EdgeInsets.zero,
                                    child: Column(children: [
                                      if (plan.items.every((x) => x.group != g.code))
                                        Padding(
                                          padding: const EdgeInsets.all(BillySpace.lg),
                                          child: Text('항목이 없습니다', style: BillyText.caption.copyWith(color: BillyColors.textHint)),
                                        ),
                                      for (final item in plan.items.where((x) => x.group == g.code)) ...[
                                        _ItemTile(
                                          item: item,
                                          plan: plan,
                                          onTap: () => _editItem(item: item),
                                          onUp: () => _move(item, -1),
                                          onDown: () => _move(item, 1),
                                        ),
                                        const Divider(height: 1),
                                      ],
                                    ]..removeLastDivider()),
                                  ),
                                ],
                                const SizedBox(height: BillySpace.md),
                                Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _addGroup, icon: const Icon(Icons.add_rounded), label: const Text('묶음 추가'))),
                                const SectionTitle('계산 방식'),
                                _advanced(plan),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    StickyActionBar(
                      leading: Text(_dirty ? '저장 안 한 변경 있음' : '항목 ${plan.items.length}개',
                          style: BillyText.captionStrong.copyWith(color: _dirty ? BillyColors.warning : BillyColors.textSecondary)),
                      children: [
                        SizedBox(height: 46, child: OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility_outlined), label: const Text('미리보기'))),
                        SizedBox(height: 46, child: FilledButton(onPressed: _dirty ? _save : null, child: const Text('저장'))),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _infoCard(PlanDef plan) {
    final presetName = switch (plan.preset) { 'legacy-v1' => '기존 방식', 'basic-v1' => '기본 상가형', 'blank' => '빈 요금표', _ => '직접 만든 요금표' };
    return BillyCard(
      color: BillyColors.primarySoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tune_rounded, color: BillyColors.primary, size: 18),
          const SizedBox(width: BillySpace.sm),
          Expanded(
            child: Text(
              _source == 'saved'
                  ? '${monthLabel(_effectiveFrom!)}부터 쓰는 요금표 · $presetName'
                  : _versions.isEmpty
                      ? '기본 요금표 · $presetName (아직 저장 안 함)'
                      : '기본 요금표 · $presetName (${monthLabel(MonthStepper.shift(_versions.last, -1))}까지)',
              style: BillyText.captionStrong.copyWith(color: BillyColors.primaryDark),
            ),
          ),
        ]),
        const SizedBox(height: BillySpace.xs),
        Text(keepAll('항목을 누르면 이름·나누는 방식·금액을 바꿀 수 있습니다. [미리보기]로 지난달에 적용하면 얼마가 되는지 먼저 확인하세요.'),
            style: BillyText.caption.copyWith(color: BillyColors.primaryDark)),
        if (_versions.isNotEmpty) ...[
          const SizedBox(height: BillySpace.sm),
          Wrap(spacing: BillySpace.xs, runSpacing: BillySpace.xs, children: [
            ChoiceChip(
              label: const Text('처음(기본)'),
              selected: _source != 'saved',
              onSelected: (_) => _source == 'saved' ? _openVersion(MonthStepper.shift(_versions.last, -1)) : null,
            ),
            for (final v in _versions.reversed)
              ChoiceChip(
                label: Text('${monthLabel(v)}부터'),
                selected: _source == 'saved' && _effectiveFrom == v,
                onSelected: (_) => _effectiveFrom == v && _source == 'saved' ? null : _openVersion(v),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _advanced(PlanDef plan) => BillyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('반올림', style: BillyText.captionStrong),
          const SizedBox(height: BillySpace.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'item', label: Text('항목마다')),
              ButtonSegment(value: 'end', label: Text('소계에서 한 번(기존)')),
            ],
            selected: {plan.roundingMode},
            onSelectionChanged: (s) => _changed(() => plan.roundingMode = s.first),
          ),
          const SizedBox(height: BillySpace.xs),
          Text(plan.roundingMode == 'item' ? '명세서 줄 금액의 합 = 소계' : '반올림 전 값으로 소계를 낸 뒤 반올림(예전 계산과 같음)',
              style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          const SizedBox(height: BillySpace.lg),
          Text('청구할 호실', style: BillyText.captionStrong),
          const SizedBox(height: BillySpace.xs),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('모든 호실')),
              ButtonSegment(value: 'with_meters', label: Text('그달 검침한 호실(기존)')),
            ],
            selected: {plan.billedUnits},
            onSelectionChanged: (s) => _changed(() => plan.billedUnits = s.first),
          ),
        ]),
      );
}

extension on List<Widget> {
  List<Widget> removeLastDivider() {
    if (isNotEmpty && last is Divider) removeLast();
    return this;
  }
}

String _inputName(String? key) => key == null ? '' : (inputLabels[key]?.$1 ?? (key.startsWith('IN_') ? '이 항목 금액' : key));

/// 항목 한 줄 요약.
String itemSummary(PlanItem i, PlanDef plan) {
  String amountText() => i.cost?.input != null
      ? (i.cost!.input!.startsWith('IN_') ? '매달 입력' : '매달 입력(${_inputName(i.cost!.input)})')
      : wonText(i.cost?.amount ?? i.amount ?? 0);
  final base = switch (i.method) {
    ChargeMethod.areaSplit => '면적 비율 · ${amountText()}',
    ChargeMethod.equalSplit => '호실 수로 똑같이 · ${amountText()}',
    ChargeMethod.usageSplit =>
      '${i.utility == 'water' ? '수도' : '전기'} 사용량 비율 · ${i.cost?.minusInputs.isNotEmpty == true ? '${_inputName(i.cost?.input)} - (${i.cost!.minusInputs.map(_inputName).join(' + ')})' : _inputName(i.cost?.input)}',
    ChargeMethod.unitPrice => '${i.utility == 'water' ? '수도' : '전기'} 사용량 × 단가(${_inputName(i.cost?.input)} ÷ ${_inputName(i.usageInput)})',
    ChargeMethod.remainder =>
      '${_inputName(i.cost?.input)}에서 사용분을 뺀 나머지 · ${switch (i.split) { 'usage' => '사용량', 'equal' => '똑같이', _ => '면적' }}으로',
    ChargeMethod.fixedPerUnit => '호실마다 ${wonText(i.amount ?? 0)}${i.perUnit.isNotEmpty ? ' (호실별 ${i.perUnit.length}곳 다름)' : ''}',
    ChargeMethod.percentOf =>
      '${i.refs.map((r) => plan.items.where((x) => x.code == r).map((x) => x.label).firstOrNull ?? r).join(' + ')}의 ${num2((i.rate ?? 0) * 100)}%',
    ChargeMethod.unitAttr => '호실에 정해 둔 고정 금액',
    ChargeMethod.direct => '그달 호실별로 직접 입력',
  };
  final scope = [
    if (i.scopeOnly.isNotEmpty) '${i.scopeOnly.join('·')}호만',
    if (i.scopeExclude.isNotEmpty) '${i.scopeExclude.join('·')}호 제외',
  ];
  return [base, ...scope].join(' · ');
}

class _ItemTile extends StatelessWidget {
  final PlanItem item;
  final PlanDef plan;
  final VoidCallback onTap;
  final VoidCallback onUp;
  final VoidCallback onDown;
  const _ItemTile({required this.item, required this.plan, required this.onTap, required this.onUp, required this.onDown});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BillySpace.lg, BillySpace.md, BillySpace.xs, BillySpace.md),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(item.label.isEmpty ? '(이름 없음)' : item.label, style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (item.hidden) ...[const SizedBox(width: BillySpace.xs), const StatusChip('숨김')],
              ]),
              const SizedBox(height: 2),
              Text(itemSummary(item, plan), style: BillyText.caption.copyWith(color: BillyColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.category != null) ...[
                const SizedBox(height: BillySpace.xs),
                StatusChip('법정: ${item.category}', tone: Tone.info),
              ],
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(tooltip: '위로', visualDensity: VisualDensity.compact, onPressed: onUp, icon: const Icon(Icons.keyboard_arrow_up_rounded)),
            IconButton(tooltip: '아래로', visualDensity: VisualDensity.compact, onPressed: onDown, icon: const Icon(Icons.keyboard_arrow_down_rounded)),
          ]),
        ]),
      ),
    );
  }
}

/// 항목 편집 — 방식에 따라 필요한 칸만 보인다. 결과: (고친 항목, 삭제 여부).
class _ItemEditor extends StatefulWidget {
  final PlanItem item;
  final PlanDef plan;
  final List<PlanItem> before; // 이 항목보다 앞의 항목(% · 남는 금액이 참조할 수 있는 것)
  final bool isNew;
  const _ItemEditor({required this.item, required this.plan, required this.before, required this.isNew});

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final PlanItem it = widget.item;
  late final _label = TextEditingController(text: it.label);
  late final _amount = TextEditingController(text: _fmt(it.cost?.amount ?? it.amount));
  late final _rate = TextEditingController(text: it.rate == null ? '' : num2(it.rate! * 100));
  late final Map<int, TextEditingController> _perUnit = {};
  late bool _monthly = it.cost?.input != null && (it.method == ChargeMethod.areaSplit || it.method == ChargeMethod.equalSplit);

  static String _fmt(double? v) => v == null || v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  // 호실별 금액은 0 도 뜻이 있다(그 호실은 안 냄) — 빈칸(=기본 금액)과 구분해 보인다
  static String _fmtKeep0(double? v) => v == null ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    _rate.dispose();
    for (final c in _perUnit.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) {
    final t = c.text.replaceAll(',', '').replaceAll('원', '').trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// 요율은 '2,7' 을 2.7 로 읽는다(쉼표를 지우면 27% 가 됐다).
  double? _rateNum() {
    final t = _rate.text.replaceAll('%', '').replaceAll(',', '.').trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// 칸에 뭔가 있는데 숫자가 아님 — 예전엔 조용히 0 이 됐다('15,000원' 은 이제 읽는다).
  bool _bad(TextEditingController c) => c.text.trim().isNotEmpty && _num(c) == null;

  /// 선택 가능한 월 입력 키(기본 키 + 이 항목 전용 키).
  List<(String, String)> _inputOptions(String? utility) {
    final own = 'IN_${it.code.toUpperCase()}';
    final std = utility == 'water'
        ? const ['W_TOTAL', 'W_SUPPLY', 'W_SEWER', 'W_USAGE']
        : utility == 'electricity'
            ? const ['E_COST', 'E_USAGE']
            : const ['E_COST', 'W_TOTAL'];
    return [for (final k in std) (k, inputLabels[k]!.$1), (own, '이 항목 금액을 매달 입력')];
  }

  void _setMethod(ChargeMethod m) {
    setState(() {
      it.method = m;
      // 방식마다 필요한 기본값
      switch (m) {
        case ChargeMethod.unitPrice:
          it.utility ??= 'electricity';
          it.cost = AmountSource(input: it.utility == 'water' ? 'W_TOTAL' : 'E_COST');
          it.usageInput = it.utility == 'water' ? 'W_USAGE' : 'E_USAGE';
        case ChargeMethod.usageSplit:
          it.utility ??= 'water';
          it.cost ??= AmountSource(input: it.utility == 'water' ? 'W_TOTAL' : 'E_COST');
        case ChargeMethod.remainder:
          final firstPrice = widget.before.where((x) => x.method == ChargeMethod.unitPrice).firstOrNull;
          it.of = firstPrice?.code;
          it.cost = AmountSource(input: firstPrice?.cost?.input ?? 'E_COST');
          it.split ??= 'area';
        case ChargeMethod.percentOf:
          it.rate ??= 0.1;
          _rate.text = num2((it.rate ?? 0.1) * 100);
        default:
          break;
      }
    });
  }

  void _apply() {
    if (_label.text.trim().isEmpty) {
      showSnack(context, '항목 이름을 넣어 주세요', error: true);
      return;
    }
    if (_bad(_amount) || _perUnit.values.any(_bad)) {
      showSnack(context, '금액은 숫자로 넣어 주세요(예: 30000)', error: true);
      return;
    }
    it.label = _label.text.trim();
    switch (it.method) {
      case ChargeMethod.areaSplit:
      case ChargeMethod.equalSplit:
        if (_monthly) {
          it.cost = AmountSource(input: 'IN_${it.code.toUpperCase()}');
          it.amount = null;
        } else {
          it.cost = null;
          it.amount = _num(_amount) ?? 0;
        }
      case ChargeMethod.fixedPerUnit:
        it.amount = _num(_amount) ?? 0;
        it.perUnit = {for (final e in _perUnit.entries) if (_num(e.value) != null) '${e.key}': _num(e.value)!};
        it.cost = null;
      case ChargeMethod.percentOf:
        final r = _rateNum();
        if (r == null) {
          showSnack(context, '요율(%)을 숫자로 넣어 주세요(예: 10, 2.7)', error: true);
          return;
        }
        // 지운 항목을 가리키던 참조는 버린다(남아 있으면 저장이 계속 실패했다)
        it.refs.removeWhere((c) => !widget.before.any((x) => x.code == c));
        if (it.refs.isEmpty) {
          showSnack(context, '요율을 곱할 항목을 하나 이상 고르세요', error: true);
          return;
        }
        it.rate = r / 100;
      case ChargeMethod.remainder:
        // 화면 드롭다운에 보이는 항목으로 맞춘다 — 지운 항목을 가리키면 저장이 계속 실패했다
        final prices = widget.before.where((x) => x.method == ChargeMethod.unitPrice).toList();
        if (!prices.any((x) => x.code == it.of)) it.of = prices.firstOrNull?.code;
        if (it.of == null) {
          showSnack(context, "먼저 앞에 '사용량 × 단가' 항목이 있어야 합니다", error: true);
          return;
        }
      default:
        break;
    }
    // 방식에 안 쓰는 칸은 지운다(서버에 쓰레기 값이 남지 않게)
    if (it.method != ChargeMethod.percentOf) {
      it.refs = [];
      it.rate = null;
    }
    if (it.method != ChargeMethod.remainder) {
      it.of = null;
      it.split = null;
    }
    if (it.method != ChargeMethod.unitPrice) it.usageInput = null;
    if (it.method != ChargeMethod.unitPrice && it.method != ChargeMethod.usageSplit && it.method != ChargeMethod.remainder) it.utility = null;
    if (it.method == ChargeMethod.unitAttr || it.method == ChargeMethod.direct || it.method == ChargeMethod.percentOf) {
      it.cost = null;
      it.amount = null;
    }
    if (it.method != ChargeMethod.fixedPerUnit) it.perUnit = {};
    Navigator.pop(context, (it, false));
  }

  @override
  Widget build(BuildContext context) {
    final units = context.read<AppProvider>().units;
    final plan = widget.plan;
    return Padding(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.isNew ? '항목 추가' : '항목 수정', style: BillyText.title),
            const SizedBox(height: BillySpace.lg),
            TextField(
              controller: _label,
              inputFormatters: [LengthLimitingTextInputFormatter(60)], // 서버가 60자에서 자른다
              decoration: const InputDecoration(labelText: '이름', hintText: '예: 청소비'),
            ),
            const SizedBox(height: BillySpace.md),
            DropdownButtonFormField<String>(
              initialValue: plan.groups.any((g) => g.code == it.group) ? it.group : plan.groups.first.code,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '묶음'),
              items: [for (final g in plan.groups) DropdownMenuItem(value: g.code, child: Text(g.label))],
              onChanged: (v) => setState(() => it.group = v ?? it.group),
            ),
            const SizedBox(height: BillySpace.md),
            DropdownButtonFormField<ChargeMethod>(
              initialValue: it.method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '나누는 방식'),
              items: [for (final m in ChargeMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (m) => m == null ? null : _setMethod(m),
            ),
            Padding(
              padding: const EdgeInsets.only(top: BillySpace.xs),
              child: Text(keepAll(it.method.help), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            ),
            const SizedBox(height: BillySpace.md),
            ..._methodFields(units),
            const Divider(height: BillySpace.xxl),
            Text('대상 호실', style: BillyText.captionStrong),
            const SizedBox(height: BillySpace.xs),
            // 켜진 호실에만 나눈다 — 예전엔 켜진 칩이 '뺄 호실'이라 101·102 만 받으려다 그 둘을 뺐다
            Text(keepAll('켜진 호실에만 나눕니다. 뺄 호실은 눌러서 끄세요'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            const SizedBox(height: BillySpace.xs),
            Wrap(spacing: BillySpace.xs, runSpacing: BillySpace.xs, children: [
              for (final u in units)
                FilterChip(
                  label: Text('${u.unitNumber}호'),
                  selected: (it.scopeOnly.isEmpty || it.scopeOnly.contains(u.unitNumber)) && !it.scopeExclude.contains(u.unitNumber),
                  onSelected: (on) => setState(() {
                    if (it.scopeOnly.isNotEmpty) {
                      on ? it.scopeOnly.add(u.unitNumber) : it.scopeOnly.remove(u.unitNumber);
                      it.scopeExclude.remove(u.unitNumber);
                    } else {
                      on ? it.scopeExclude.remove(u.unitNumber) : it.scopeExclude.add(u.unitNumber);
                    }
                  }),
                ),
            ]),
            const SizedBox(height: BillySpace.md),
            DropdownButtonFormField<String>(
              initialValue: legalCategories.contains(it.category) ? it.category : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: '법정 관리비 분류', helperText: '상가임대차법 14항목 — 임차인 요청 시 내역 제공용'),
              items: [const DropdownMenuItem(value: '', child: Text('(분류 없음)')), for (final c in legalCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => it.category = (v == null || v.isEmpty) ? null : v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('명세서 줄에서 숨기기'),
              subtitle: Text('합계에는 들어갑니다', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
              value: it.hidden,
              onChanged: (v) => setState(() => it.hidden = v),
            ),
            const SizedBox(height: BillySpace.md),
            FilledButton(onPressed: _apply, child: Text(widget.isNew ? '추가' : '적용')),
            if (!widget.isNew) ...[
              const SizedBox(height: BillySpace.sm),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: BillyColors.error),
                onPressed: () => Navigator.pop(context, (null, true)),
                child: const Text('항목 삭제'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _methodFields(List<UnitV2> units) {
    Widget utilityPicker() => SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'electricity', label: Text('전기')), ButtonSegment(value: 'water', label: Text('수도'))],
          selected: {it.utility ?? 'electricity'},
          onSelectionChanged: (s) => setState(() {
            it.utility = s.first;
            if (it.method == ChargeMethod.unitPrice) {
              it.cost = AmountSource(input: s.first == 'water' ? 'W_TOTAL' : 'E_COST');
              it.usageInput = s.first == 'water' ? 'W_USAGE' : 'E_USAGE';
            }
          }),
        );
    Widget inputPicker(String label, String? value, ValueChanged<String> onChanged, {String? utility}) {
      final opts = _inputOptions(utility);
      final v = opts.any((o) => o.$1 == value) ? value : null;
      return DropdownButtonFormField<String>(
        initialValue: v,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final o in opts) DropdownMenuItem(value: o.$1, child: Text(o.$2))],
        onChanged: (x) => x == null ? null : setState(() => onChanged(x)),
      );
    }

    switch (it.method) {
      case ChargeMethod.areaSplit:
      case ChargeMethod.equalSplit:
        return [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('매달 같은 금액')), ButtonSegment(value: true, label: Text('매달 입력'))],
            selected: {_monthly},
            onSelectionChanged: (s) => setState(() => _monthly = s.first),
          ),
          const SizedBox(height: BillySpace.md),
          if (!_monthly)
            TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '한 달 전체 금액', suffixText: '원', helperText: '이 금액을 호실에 나눕니다'))
          else
            Text(keepAll('정산 2단계(고지서) 화면에 이 항목의 금액 칸이 생깁니다.'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
        ];
      case ChargeMethod.usageSplit:
        return [
          utilityPicker(),
          const SizedBox(height: BillySpace.md),
          if (it.cost?.minusInputs.isNotEmpty == true)
            Text('나눌 금액: ${_inputName(it.cost?.input)} - (${it.cost!.minusInputs.map(_inputName).join(' + ')}) — 기존 공동요금 식',
                style: BillyText.caption.copyWith(color: BillyColors.textSecondary))
          else
            inputPicker('나눌 금액(고지서)', it.cost?.input, (x) => it.cost = AmountSource(input: x), utility: it.utility),
        ];
      case ChargeMethod.unitPrice:
        return [
          utilityPicker(),
          const SizedBox(height: BillySpace.md),
          inputPicker('고지서 금액', it.cost?.input, (x) => it.cost = AmountSource(input: x), utility: it.utility),
          const SizedBox(height: BillySpace.md),
          inputPicker('고지서 총 사용량', it.usageInput, (x) => it.usageInput = x, utility: it.utility),
        ];
      case ChargeMethod.remainder:
        final prices = widget.before.where((x) => x.method == ChargeMethod.unitPrice).toList();
        return [
          if (prices.isEmpty)
            Text(keepAll("이 항목보다 앞에 '사용량 × 단가' 항목을 먼저 만들어 주세요."), style: BillyText.caption.copyWith(color: BillyColors.error))
          else
            DropdownButtonFormField<String>(
              initialValue: prices.any((x) => x.code == it.of) ? it.of : prices.first.code,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '빼는 사용분 항목'),
              items: [for (final x in prices) DropdownMenuItem(value: x.code, child: Text(x.label))],
              onChanged: (v) => setState(() => it.of = v),
            ),
          const SizedBox(height: BillySpace.md),
          inputPicker('전체 금액(고지서)', it.cost?.input, (x) => it.cost = AmountSource(input: x)),
          const SizedBox(height: BillySpace.md),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'area', label: Text('면적')), ButtonSegment(value: 'usage', label: Text('사용량')), ButtonSegment(value: 'equal', label: Text('똑같이'))],
            selected: {it.split ?? 'area'},
            onSelectionChanged: (s) => setState(() => it.split = s.first),
          ),
        ];
      case ChargeMethod.fixedPerUnit:
        return [
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '호실마다 금액', suffixText: '원')),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('호실별로 다르게', style: BillyText.bodyStrong),
            subtitle: Text('비우면 위 금액 · 0 이면 그 호실은 안 냄', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            children: [
              for (final u in units)
                Padding(
                  padding: const EdgeInsets.only(bottom: BillySpace.sm),
                  child: TextField(
                    controller: _perUnit.putIfAbsent(u.unitNumber, () => TextEditingController(text: _fmtKeep0(it.perUnit['${u.unitNumber}']))),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: u.title, suffixText: '원'),
                  ),
                ),
            ],
          ),
        ];
      case ChargeMethod.percentOf:
        final candidates = widget.before.where((x) => x.code != it.code).toList();
        return [
          Text('요율을 곱할 항목', style: BillyText.captionStrong),
          const SizedBox(height: BillySpace.xs),
          if (candidates.isEmpty)
            Text(keepAll('앞에 있는 항목이 없습니다. 이 항목을 대상 항목들 뒤에 두세요.'), style: BillyText.caption.copyWith(color: BillyColors.error))
          else
            Wrap(spacing: BillySpace.xs, runSpacing: BillySpace.xs, children: [
              for (final x in candidates)
                FilterChip(
                  label: Text(x.label),
                  selected: it.refs.contains(x.code),
                  onSelected: (v) => setState(() => v ? it.refs.add(x.code) : it.refs.remove(x.code)),
                ),
              // 지운 항목(또는 이 항목보다 아래로 간 항목)을 가리키는 참조 — 적용하면 빠진다
              for (final r in it.refs.where((r) => !candidates.any((x) => x.code == r)).toList())
                FilterChip(
                  label: const Text('없는 항목'),
                  selected: true,
                  onSelected: (_) => setState(() => it.refs.remove(r)),
                ),
            ]),
          const SizedBox(height: BillySpace.md),
          TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '요율', suffixText: '%', helperText: '부가세 10, 전력산업기반기금 2.7')),
        ];
      case ChargeMethod.unitAttr:
        return [Text(keepAll("호실 화면의 '고정 금액'(화재보험료 등)을 그대로 씁니다."), style: BillyText.caption.copyWith(color: BillyColors.textSecondary))];
      case ChargeMethod.direct:
        return [Text(keepAll('정산 2단계(고지서) 화면에서 그달 호실별 금액을 직접 넣습니다.'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary))];
    }
  }
}

/// 미리보기 — 고른 달에 지금 요금표와 고친 요금표를 적용한 호실별 금액 비교(아무것도 저장하지 않는다).
class _PreviewSheet extends StatefulWidget {
  final PlanDef plan;
  const _PreviewSheet({required this.plan});

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  late String _month = MonthStepper.shift(context.read<AppProvider>().workingMonth, -1);
  PreviewV2? _now;
  PreviewV2? _draft;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  int _seq = 0; // 달을 빠르게 넘기면 늦게 온 옛 달 응답이 새 달 이름 아래 보였다

  Future<void> _run() async {
    final p = context.read<AppProvider>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([p.api.previewMonth(p.buildingId!, _month), p.api.previewPlan(p.buildingId!, _month, widget.plan)]);
      if (!mounted || seq != _seq) return;
      setState(() {
        _now = results[0];
        _draft = results[1];
        _loading = false;
      });
    } catch (e) {
      if (mounted && seq == _seq) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Widget _diff(double? before, double after) => before == null
      ? const SizedBox()
      : MoneyText(after - before, size: 13, signed: true,
          color: after - before == 0 ? BillyColors.textHint : (after > before ? BillyColors.error : BillyColors.success));

  /// 호실별 비교표. 폰처럼 좁으면 '지금' 칸을 호실 이름 아래로 내린다.
  Widget _table(Map<int, double> now, List<UnitBill> draft, bool narrow) {
    final nowTotal = now.values.fold(0.0, (s, v) => s + v);
    Widget row(Widget title, double? before, double after, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: BillySpace.sm),
          child: Row(children: [
            Expanded(child: title),
            if (!narrow)
              SizedBox(width: 96, child: before == null ? const Text('-', textAlign: TextAlign.right) : MoneyText(before, size: 13, weight: FontWeight.w400)),
            SizedBox(width: narrow ? 92 : 96, child: MoneyText(after, size: 13)),
            SizedBox(width: narrow ? 80 : 88, child: _diff(before, after)),
          ]),
        );
    Widget title(String text, double? before, {TextStyle? style}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: style ?? BillyText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (narrow && before != null) Text('지금 ${wonText(before)}', style: BillyText.tiny.copyWith(color: BillyColors.textSecondary, fontWeight: FontWeight.w400)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: BillySpace.sm),
        child: Row(children: [
          Expanded(child: Text('호실', style: BillyText.captionStrong)),
          if (!narrow) SizedBox(width: 96, child: Text('지금', textAlign: TextAlign.right, style: BillyText.captionStrong)),
          SizedBox(width: narrow ? 92 : 96, child: Text('바꾸면', textAlign: TextAlign.right, style: BillyText.captionStrong)),
          SizedBox(width: narrow ? 80 : 88, child: Text('차이', textAlign: TextAlign.right, style: BillyText.captionStrong)),
        ]),
      ),
      const Divider(height: 1),
      for (final u in draft) row(title(u.title, now[u.unitNumber]), now[u.unitNumber], u.total),
      const Divider(height: 1),
      row(title('합계', nowTotal, style: BillyText.bodyStrong), nowTotal, _draft!.total),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final now = {for (final u in _now?.units ?? const <UnitBill>[]) u.unitNumber: u.total};
    final draft = _draft?.units ?? const <UnitBill>[];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, BillySpace.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('미리보기', style: BillyText.title),
          const SizedBox(height: BillySpace.xs),
          Text(keepAll('고른 달의 검침·고지서로 계산합니다. 저장하지 않습니다.'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          const SizedBox(height: BillySpace.md),
          Align(
            alignment: Alignment.centerLeft,
            child: MonthStepper(month: _month, dense: true, onChanged: (m) {
              setState(() => _month = m);
              _run();
            }),
          ),
          const SizedBox(height: BillySpace.md),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorBanner(message: errorText(_error!), onRetry: _run)
                    : LayoutBuilder(
                        builder: (context, c) => ListView(children: [
                          if (_draft != null) IssueList(_draft!.issues),
                          if (draft.isNotEmpty) _table(now, draft, c.maxWidth < 440),
                        ]),
                      ),
          ),
        ]),
      ),
    );
  }
}
