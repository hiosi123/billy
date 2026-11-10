import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../models/room.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 호실 — 청구 단위(면적·고정 금액)와 그 호실의 계량기(배수·고정 사용량).
class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalArea = p.units.fold(0.0, (s, u) => s + u.area);
    final meters = p.units.fold(0, (s, u) => s + u.meters.length);
    return Scaffold(
      appBar: buildingAppBar(context, '호실', actions: [
        TextButton.icon(onPressed: () => _addUnit(context), icon: const Icon(Icons.add_rounded), label: const Text('호실 추가')),
        const SizedBox(width: BillySpace.xs),
      ]),
      body: RefreshIndicator(
        onRefresh: p.reloadStructure,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, BillySpace.xxxl),
          children: [
            ContentWidth(
              max: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('호실 ${p.units.length}곳 · 계량기 $meters개 · 전체 면적 ${num2(totalArea)}m²',
                      style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
                  const SizedBox(height: BillySpace.md),
                  if (p.units.isEmpty)
                    EmptyView(
                      icon: Icons.meeting_room_outlined,
                      message: '호실이 없습니다.\n호실을 추가하면 계량기도 함께 만들어집니다.',
                      action: FilledButton(onPressed: () => _addUnit(context), child: const Text('호실 추가')),
                    )
                  else
                    for (final u in p.units)
                      Padding(
                        padding: const EdgeInsets.only(bottom: BillySpace.sm),
                        child: BillyCard(
                          onTap: () => _editUnit(context, u),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                padding: const EdgeInsets.symmetric(vertical: BillySpace.sm),
                                decoration: BoxDecoration(color: BillyColors.primarySoft, borderRadius: BorderRadius.circular(BillyRadius.md)),
                                child: Text('${u.unitNumber}', textAlign: TextAlign.center, style: BillyText.bodyStrong.copyWith(color: BillyColors.primaryDark)),
                              ),
                              const SizedBox(width: BillySpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name.isEmpty ? '(이름 없음)' : u.name, style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    DotLine(['면적 ${num2(u.area)}m²', if (u.baseCost > 0) '고정 금액 ${wonText(u.baseCost)}', if (u.floor != null) '${u.floor}층']),
                                    const SizedBox(height: BillySpace.sm),
                                    Wrap(spacing: BillySpace.xs, runSpacing: BillySpace.xs, children: [
                                      for (final m in u.meters)
                                        StatusChip(
                                          [
                                            m.label.isEmpty ? '계량기' : m.label,
                                            if (m.measureMultiply != 1) '×${num2(m.measureMultiply)}',
                                            if (m.strictWater > 0) '수도 고정 ${num2(m.strictWater)}',
                                            if (m.strictElectricity > 0) '전기 고정 ${num2(m.strictElectricity)}',
                                          ].join(' '),
                                          tone: Tone.neutral,
                                          icon: Icons.speed_rounded,
                                        ),
                                    ]),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editUnit(BuildContext context, UnitV2 u) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => _UnitSheet(unit: u),
      );

  void _addUnit(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        builder: (_) => const _NewUnitSheet(),
      );
}

double? _num(TextEditingController c) {
  final t = c.text.replaceAll(',', '').replaceAll('원', '').trim();
  return t.isEmpty ? null : double.tryParse(t);
}

/// 칸에 뭔가 있는데 숫자가 아님 — 예전엔 조용히 0 이 돼 화재보험료 같은 금액이 지워졌다.
bool _bad(TextEditingController c) => c.text.trim().isNotEmpty && _num(c) == null;

/// 호실 수정 + 그 호실의 계량기 관리.
class _UnitSheet extends StatefulWidget {
  final UnitV2 unit;
  const _UnitSheet({required this.unit});

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  late final _name = TextEditingController(text: widget.unit.name);
  late final _area = TextEditingController(text: num2(widget.unit.area).replaceAll(',', ''));
  late final _base = TextEditingController(text: widget.unit.baseCost == 0 ? '' : widget.unit.baseCost.round().toString());
  bool _busy = false; // 두 번 눌러 두 번 저장하거나 창이 두 번 닫혀 뒤 화면까지 닫히지 않게

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _base.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final p = context.read<AppProvider>();
    final area = _num(_area);
    if (area == null || area < 0) {
      showSnack(context, '면적을 숫자로 넣어 주세요', error: true);
      return;
    }
    if (_bad(_base) || (_num(_base) ?? 0) < 0) {
      showSnack(context, '고정 금액은 0 이상의 숫자로 넣어 주세요', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await p.api.updateUnit(p.buildingId!, widget.unit.unitId, {'name': _name.text.trim(), 'area': area, 'baseCost': _num(_base) ?? 0});
      await p.reloadStructure();
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, '${widget.unit.unitNumber}호를 저장했습니다');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  /// 계량기가 없는 호실만 — 잘못 만든 호실 정리(남아 있으면 '모든 호실' 항목에서 몫을 받았다).
  Future<void> _deleteUnit() async {
    final u = widget.unit;
    final ok = await confirmAction(context, title: '${u.unitNumber}호를 지울까요?', message: '계량기가 없는 호실입니다. 이미 확정한 명세서는 그대로 남습니다.', ok: '지우기');
    if (!ok || !mounted) return;
    final p = context.read<AppProvider>();
    setState(() => _busy = true);
    try {
      await p.api.deleteUnit(p.buildingId!, u.unitId);
      await p.reloadStructure();
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, '${u.unitNumber}호를 지웠습니다');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  Room? _room(int id) {
    for (final r in context.read<AppProvider>().rooms) {
      if (r.roomId == id) return r;
    }
    return null;
  }

  Future<void> _editMeter(MeterV2? m) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _MeterSheet(unit: widget.unit, room: m == null ? null : _room(m.roomId)),
    );
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final unit = p.units.firstWhere((x) => x.unitId == widget.unit.unitId, orElse: () => widget.unit);
    return Padding(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${unit.unitNumber}호', style: BillyText.title),
            const SizedBox(height: BillySpace.lg),
            TextField(controller: _name, decoration: const InputDecoration(labelText: '이름(입주사)')),
            const SizedBox(height: BillySpace.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _area,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '면적', suffixText: 'm²', helperText: '면적 비율 항목에 쓰입니다'),
                ),
              ),
              const SizedBox(width: BillySpace.md),
              Expanded(
                child: TextField(
                  controller: _base,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '고정 금액', suffixText: '원', helperText: '화재보험료 등'),
                ),
              ),
            ]),
            const SizedBox(height: BillySpace.md),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('호실 저장')),
            const SectionTitle('계량기', subtitle: '검침하는 단위. 같은 호실에 여러 개를 둘 수 있습니다'),
            for (final m in unit.meters)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.speed_rounded, color: BillyColors.textSecondary),
                title: Text(m.label.isEmpty ? '계량기' : m.label, style: BillyText.bodyStrong),
                subtitle: DotLine(['배수 ×${num2(m.measureMultiply)}', if (m.strictWater > 0) '수도 고정 ${num2(m.strictWater)}m³', if (m.strictElectricity > 0) '전기 고정 ${num2(m.strictElectricity)}kWh']),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: () => _editMeter(m),
              ),
            OutlinedButton.icon(onPressed: () => _editMeter(null), icon: const Icon(Icons.add_rounded), label: const Text('계량기 추가')),
            if (unit.meters.isEmpty) ...[
              const SizedBox(height: BillySpace.sm),
              TextButton(
                onPressed: _busy ? null : _deleteUnit,
                style: TextButton.styleFrom(foregroundColor: BillyColors.error),
                child: const Text('호실 삭제'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 계량기 추가·수정·삭제(기존 rooms 행).
class _MeterSheet extends StatefulWidget {
  final UnitV2 unit;
  final Room? room;
  const _MeterSheet({required this.unit, this.room});

  @override
  State<_MeterSheet> createState() => _MeterSheetState();
}

class _MeterSheetState extends State<_MeterSheet> {
  // 이름 없는 호실이면 호수로(예전엔 '-2' 같은 이름이 생겼다)
  late final _label = TextEditingController(
      text: widget.room?.measureMachine ?? '${widget.unit.name.isEmpty ? '${widget.unit.unitNumber}' : widget.unit.name}-${widget.unit.meters.length + 1}');
  bool _busy = false;
  late final _multi = TextEditingController(text: widget.room == null ? '1' : num2(widget.room!.measureMultiply).replaceAll(',', ''));
  late final _sw = TextEditingController(text: (widget.room?.strictWater ?? 0) > 0 ? num2(widget.room!.strictWater) : '');
  late final _se = TextEditingController(text: (widget.room?.strictElectricity ?? 0) > 0 ? num2(widget.room!.strictElectricity) : '');

  @override
  void dispose() {
    for (final c in [_label, _multi, _sw, _se]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final p = context.read<AppProvider>();
    if (_bad(_multi) || _bad(_sw) || _bad(_se)) {
      showSnack(context, '배수·고정 사용량은 숫자로 넣어 주세요', error: true);
      return;
    }
    final multi = _num(_multi) ?? 1;
    if (multi <= 0) {
      showSnack(context, '배수는 0보다 커야 합니다', error: true);
      return;
    }
    final data = {
      'measureMachine': _label.text.trim(),
      'measureMultiply': multi,
      'strictWater': _num(_sw) ?? 0,
      'strictElectricity': _num(_se) ?? 0,
    };
    final floorId = widget.unit.floorId ?? (p.floors.isNotEmpty ? p.floors.first.floorId : null);
    if (widget.room == null && floorId == null) {
      showSnack(context, '먼저 층을 하나 만들어 주세요', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.room == null) {
        await p.api.createRoom({
          ...data,
          'roomNumber': widget.unit.unitNumber,
          'roomName': widget.unit.name,
          'roomSpace': 0,
          'roomBaseCost': 0,
          'floorId': floorId,
          'buildingId': p.buildingId,
        });
      } else {
        await p.api.updateRoom(widget.room!.roomId, data);
      }
      await p.reloadStructure();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  Future<void> _delete() async {
    final r = widget.room!;
    final name = r.measureMachine.isEmpty ? '${r.roomNumber}' : r.measureMachine;
    final ok = await confirmTypedDelete(context, title: '계량기 삭제', name: name, detail: "'$name' 계량기와 그 검침 기록이 모두 지워집니다.");
    if (!ok || !mounted) return;
    final p = context.read<AppProvider>();
    setState(() => _busy = true);
    try {
      await p.api.deleteRoom(r.roomId);
      await p.reloadStructure();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.room == null ? '${widget.unit.unitNumber}호에 계량기 추가' : '계량기 수정', style: BillyText.title),
            const SizedBox(height: BillySpace.lg),
            TextField(controller: _label, decoration: const InputDecoration(labelText: '계량기 이름', helperText: '같은 호실 계량기를 구분하는 이름(예: 천리안안과-1)')),
            const SizedBox(height: BillySpace.md),
            TextField(
              controller: _multi,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '전기 배수', helperText: '변류기(CT) 계량기면 ×25 등 — 사용량에 곱합니다'),
            ),
            const SizedBox(height: BillySpace.md),
            Row(children: [
              Expanded(child: TextField(controller: _sw, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '수도 고정 사용량', suffixText: 'm³'))),
              const SizedBox(width: BillySpace.md),
              Expanded(child: TextField(controller: _se, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '전기 고정 사용량', suffixText: 'kWh'))),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: BillySpace.xs),
              child: Text(keepAll('고정 사용량을 넣으면 지침과 상관없이 그 값으로 계산합니다(비우면 지침대로).'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
            ),
            const SizedBox(height: BillySpace.lg),
            FilledButton(onPressed: _busy ? null : _save, child: Text(widget.room == null ? '추가' : '저장')),
            if (widget.room != null) ...[
              const SizedBox(height: BillySpace.sm),
              TextButton(onPressed: _busy ? null : _delete, style: TextButton.styleFrom(foregroundColor: BillyColors.error), child: const Text('계량기 삭제')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 새 호실 — 호수·이름·면적·층 + 첫 계량기.
class _NewUnitSheet extends StatefulWidget {
  const _NewUnitSheet();

  @override
  State<_NewUnitSheet> createState() => _NewUnitSheetState();
}

class _NewUnitSheetState extends State<_NewUnitSheet> {
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _area = TextEditingController();
  final _base = TextEditingController();
  final _multi = TextEditingController(text: '1');
  int? _floorId;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_number, _name, _area, _base, _multi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addFloor() async {
    final p = context.read<AppProvider>();
    final next = (p.floors.isEmpty ? 0 : p.floors.map((f) => f.floor).reduce((a, b) => a > b ? a : b)) + 1;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await p.api.createFloor({'floor': next, 'floorSpace': 0, 'buildingId': p.buildingId});
      await p.reloadStructure();
      if (!mounted) return;
      setState(() => _floorId = p.floors.firstWhere((f) => f.floor == next).floorId);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final p = context.read<AppProvider>();
    final number = int.tryParse(_number.text.replaceAll('호', '').trim());
    if (number == null || number <= 0) {
      showSnack(context, '호수를 숫자로 넣어 주세요(예: 101)', error: true);
      return;
    }
    // 계량기 창과 같은 검사 — 배수 0 은 전기를 0 으로, 빈 면적은 면적 몫 0 으로 만들었다
    final area = _num(_area);
    if (area == null || area < 0) {
      showSnack(context, '면적을 숫자로 넣어 주세요(없으면 0)', error: true);
      return;
    }
    if (_bad(_base) || (_num(_base) ?? 0) < 0) {
      showSnack(context, '고정 금액은 0 이상의 숫자로 넣어 주세요', error: true);
      return;
    }
    if (_bad(_multi) || (_num(_multi) ?? 1) <= 0) {
      showSnack(context, '전기 배수는 0보다 큰 숫자여야 합니다', error: true);
      return;
    }
    if (p.units.any((u) => u.unitNumber == number)) {
      showSnack(context, '$number호가 이미 있습니다. 계량기를 더하려면 그 호실을 눌러 주세요', error: true);
      return;
    }
    final floorId = _floorId ?? (p.floors.isNotEmpty ? p.floors.first.floorId : null);
    if (floorId == null) {
      showSnack(context, '먼저 층을 만들어 주세요', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await p.api.createRoom({
        'roomNumber': number,
        'roomName': _name.text.trim(),
        'measureMachine': _name.text.trim().isEmpty ? '$number' : _name.text.trim(),
        'roomSpace': area,
        'roomBaseCost': _num(_base) ?? 0,
        'measureMultiply': _num(_multi) ?? 1,
        'floorId': floorId,
        'buildingId': p.buildingId,
      });
      await p.reloadStructure();
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, '$number호를 만들었습니다');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final floors = [...p.floors]..sort((a, b) => a.floor.compareTo(b.floor));
    return Padding(
      padding: EdgeInsets.fromLTRB(BillySpace.xl, 0, BillySpace.xl, MediaQuery.of(context).viewInsets.bottom + BillySpace.xl),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('호실 추가', style: BillyText.title),
            const SizedBox(height: BillySpace.lg),
            Row(children: [
              Expanded(child: TextField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '호수', hintText: '101'))),
              const SizedBox(width: BillySpace.md),
              Expanded(flex: 2, child: TextField(controller: _name, decoration: const InputDecoration(labelText: '이름(입주사)'))),
            ]),
            const SizedBox(height: BillySpace.md),
            Row(children: [
              Expanded(child: TextField(controller: _area, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '면적', suffixText: 'm²'))),
              const SizedBox(width: BillySpace.md),
              Expanded(child: TextField(controller: _base, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '고정 금액', suffixText: '원'))),
            ]),
            const SizedBox(height: BillySpace.md),
            TextField(controller: _multi, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '첫 계량기 전기 배수')),
            const SizedBox(height: BillySpace.md),
            Text('층', style: BillyText.captionStrong),
            const SizedBox(height: BillySpace.xs),
            Wrap(spacing: BillySpace.xs, runSpacing: BillySpace.xs, children: [
              for (final f in floors)
                ChoiceChip(
                  label: Text('${f.floor}층'),
                  selected: (_floorId ?? floors.first.floorId) == f.floorId,
                  onSelected: (_) => setState(() => _floorId = f.floorId),
                ),
              ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: const Text('층 추가'), onPressed: _busy ? null : _addFloor),
            ]),
            const SizedBox(height: BillySpace.lg),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('만들기')),
          ],
        ),
      ),
    );
  }
}
