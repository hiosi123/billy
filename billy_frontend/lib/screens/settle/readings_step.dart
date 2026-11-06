import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../models/bill.dart';
import '../../models/bill_photo.dart';
import '../../models/room.dart';
import '../../utils/format.dart';
import '../../utils/image_pick.dart';
import '../../utils/meter_check.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 정산 1단계 — 검침. 호실별로 계량기를 묶어 보여 주고, 저장 전에 빈칸·소수점·감소를 확인한다.
class ReadingsStep extends StatefulWidget {
  final String month;
  final VoidCallback onNext;
  const ReadingsStep({super.key, required this.month, required this.onNext});

  @override
  State<ReadingsStep> createState() => _ReadingsStepState();
}

class _ReadingsStepState extends State<ReadingsStep> {
  bool _loading = true; // 첫 프레임부터 스피너(컨트롤러가 생기기 전에 카드를 그리지 않게)
  // 그 달을 불러오지 못함 — 이때는 카드를 숨기고 저장을 막는다. 실패한 채로 두면
  // 이전 달 숫자가 새 달 이름으로 저장됐다(2026-11 점검에서 재현).
  bool _loadFailed = false;
  int _loadSeq = 0; // 늦게 도착한 이전 달 응답을 버리기 위한 순번
  Map<int, BillInfo> _byRoom = {}; // roomId -> 이번달 청구
  Map<int, BillInfo> _lastByRoom = {}; // roomId -> 지난달 청구(검침값·사용량)
  Map<int, BillInfo> _last2ByRoom = {}; // roomId -> 지지난달 청구(오차범위 비교용)
  final Map<int, TextEditingController> _water = {};
  final Map<int, TextEditingController> _elec = {};
  // 촬영/저장 사진. 키: 'roomId-water' | 'roomId-electricity'. 저장 시 S3 URL로 갱신.
  final Map<String, BillPhoto> _photos = {};

  static String _prevMonth(String yyyymm) {
    final y = int.parse(yyyymm.substring(0, 4));
    final m = int.parse(yyyymm.substring(4, 6));
    final d = DateTime(y, m - 1, 1);
    return '${d.year}${d.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant ReadingsStep old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _load();
  }

  @override
  void dispose() {
    for (final c in _water.values) {
      c.dispose();
    }
    for (final c in _elec.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(Map<int, TextEditingController> m, int roomId) =>
      m.putIfAbsent(roomId, () => TextEditingController());

  /// 그 달 검침을 불러온다. 먼저 입력을 비우고 시작한다 —
  /// 실패하거나 응답이 늦게 와도 이전 달 숫자가 새 달 이름으로 남지 않게.
  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final seq = ++_loadSeq;
    final buildingId = p.building!.buildingId;
    final month = widget.month;
    setState(() {
      _loading = true;
      _loadFailed = false;
      _byRoom = {};
      _lastByRoom = {};
      _last2ByRoom = {};
      _photos.clear();
      for (final c in [..._water.values, ..._elec.values]) {
        c.clear();
      }
    });
    try {
      final prev1 = _prevMonth(month);
      final prev2 = _prevMonth(prev1);
      final results = await Future.wait([
        p.api.getBillsByCondition(month: month, buildingId: buildingId),
        p.api.getBillsByCondition(month: prev1, buildingId: buildingId),
        p.api.getBillsByCondition(month: prev2, buildingId: buildingId),
      ]);
      if (!mounted || seq != _loadSeq) return; // 그새 달·건물이 바뀌었으면 버린다
      _byRoom = {for (final i in results[0]) i.roomId: i};
      _lastByRoom = {for (final i in results[1]) i.roomId: i};
      _last2ByRoom = {for (final i in results[2]) i.roomId: i};
      for (final r in p.rooms) {
        final info = _byRoom[r.roomId];
        _ctl(_water, r.roomId).text = info != null && info.waterMeasure > 0 ? num2(info.waterMeasure) : '';
        _ctl(_elec, r.roomId).text = info != null && info.electricityMeasure > 0 ? num2(info.electricityMeasure) : '';
        // 저장돼 있던 계량기 사진(S3 URL) 복원
        if (info?.waterMeterPhoto != null) _photos['${r.roomId}-water'] = BillPhoto(url: info!.waterMeterPhoto);
        if (info?.electricityMeterPhoto != null) {
          _photos['${r.roomId}-electricity'] = BillPhoto(url: info!.electricityMeterPhoto);
        }
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  bool get _ready => !_loading && !_loadFailed;

  /// 계량기 표시 이름 — 같은 호수에 계량기가 여럿이면 계량기 명칭(천리안안과-1)으로 구분한다.
  static String _meterName(Room r) => r.measureMachine.isNotEmpty ? r.measureMachine : r.roomName;

  /// 지난달 지침이 있는데 이번 달 칸이 빈 항목('수도'/'전기').
  /// 빈칸은 0 으로 저장되고, 서버는 0 을 '계량기가 한 바퀴 돈 것'으로 읽어 가짜 사용량을 만든다.
  List<String> _blankFields(Room r) {
    final last = _lastByRoom[r.roomId];
    return [
      if (_parse(_water[r.roomId]) == null && (last?.waterMeasure ?? 0) > 0) '수도',
      if (_parse(_elec[r.roomId]) == null && (last?.electricityMeasure ?? 0) > 0) '전기',
    ];
  }

  /// 콤마가 섞여 있어도 안전하게 파싱(빈칸이면 null).
  double? _parse(TextEditingController? c) {
    final t = c?.text.replaceAll(',', '').trim() ?? '';
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// 이번달/지난달 청구 맵만 다시 불러온다(입력 컨트롤러는 건드리지 않음).
  Future<void> _reloadMaps() async {
    final p = context.read<AppProvider>();
    final buildingId = p.building!.buildingId;
    final prev1 = _prevMonth(widget.month);
    final prev2 = _prevMonth(prev1);
    final results = await Future.wait([
      p.api.getBillsByCondition(month: widget.month, buildingId: buildingId),
      p.api.getBillsByCondition(month: prev1, buildingId: buildingId),
      p.api.getBillsByCondition(month: prev2, buildingId: buildingId),
    ]);
    _byRoom = {for (final i in results[0]) i.roomId: i};
    _lastByRoom = {for (final i in results[1]) i.roomId: i};
    _last2ByRoom = {for (final i in results[2]) i.roomId: i};
  }

  /// 저장 직후 "해당 호실만" 서버값으로 동기화. 나머지 호실의 미저장 입력은 보존된다.
  void _syncControllers(Iterable<int> roomIds) {
    for (final rid in roomIds) {
      final info = _byRoom[rid];
      if (info == null) continue;
      if (info.waterMeasure > 0) _water[rid]?.text = num2(info.waterMeasure);
      if (info.electricityMeasure > 0) _elec[rid]?.text = num2(info.electricityMeasure);
    }
  }

  /// 해당 키의 사진이 base64면 S3 업로드 후 URL 반환(이미 URL이면 그대로). 업로드 후 재업로드 방지.
  Future<String?> _uploadIfNeeded(ApiService api, String key) async {
    final photo = _photos[key];
    if (photo == null || photo.base64 == null) return photo?.url;
    final url = await api.uploadImage('meter', photo.media, base64Decode(photo.base64!));
    _photos[key] = BillPhoto(url: url);
    return url;
  }

  Future<void> _persist(Room room, String month) async {
    final p = context.read<AppProvider>();
    final api = p.api;
    final waterUrl = await _uploadIfNeeded(api, '${room.roomId}-water');
    final elecUrl = await _uploadIfNeeded(api, '${room.roomId}-electricity');
    await api.insertMeasure({
      'BuildingId': room.buildingId,
      'FloorId': room.floorId,
      'RoomId': room.roomId,
      // 빈칸은 계량기가 없는 칸뿐이다(_blankFields 가 지난달 값이 있는 빈칸을 미리 막는다)
      'WaterMeasure': _parse(_water[room.roomId]) ?? 0,
      'ElectricityMeasure': _parse(_elec[room.roomId]) ?? 0,
      'ChargeMonth': month,
      'WaterMeterPhoto': waterUrl,
      'ElectricityMeterPhoto': elecUrl,
    });
  }

  /// 저장 전에 확인할 지침: 소수점이 빠진 것 같은 값(지난달의 10배 이상)과 지난달보다 작은 값.
  ({List<_DecimalSuspect> decimals, List<_Decrease> decreases}) _readingIssues(Iterable<Room> rooms) {
    final decimals = <_DecimalSuspect>[];
    final decreases = <_Decrease>[];
    for (final r in rooms) {
      final last = _lastByRoom[r.roomId];
      final multiply = r.measureMultiply > 0 ? r.measureMultiply : 1.0;
      for (final (kind, ctl, lastReading, multi) in [
        ('수도', _water[r.roomId], last?.waterMeasure, 1.0),
        ('전기', _elec[r.roomId], last?.electricityMeasure, multiply),
      ]) {
        final reading = _parse(ctl);
        if (ctl == null || reading == null) continue;
        final fix = suggestDecimalFix(reading, lastReading);
        if (fix != null) {
          decimals.add(_DecimalSuspect('${_meterName(r)} $kind', ctl, reading, fix));
        } else if (lastReading != null && lastReading > 0 && reading < lastReading) {
          decreases.add(_Decrease('${_meterName(r)} $kind', lastReading, reading, rolloverUsage(lastReading, reading, multi)));
        }
      }
    }
    return (decimals: decimals, decreases: decreases);
  }

  /// 확인할 지침이 있으면 고쳐서/그대로 저장할지 묻는다. 취소하면 false.
  /// (9월분이 소수점 없이 저장돼 계산이 막혔다 — 화면 경고만으로는 못 막았다.
  ///  지난달보다 작은 값은 서버가 '한 바퀴 돈 것'으로 읽어 큰 사용량을 만든다.)
  Future<bool> _confirmReadings(Iterable<Room> rooms) async {
    final (:decimals, :decreases) = _readingIssues(rooms);
    if (decimals.isEmpty && decreases.isEmpty) return true;
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final choice = await showDialog<_DecimalChoice>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(decreases.isEmpty ? '소수점이 빠졌나요?' : '확인이 필요한 검침값'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (decimals.isNotEmpty) ...[
              const Text('지난달 지침보다 10배 넘게 큰 값이 있습니다.'),
              const SizedBox(height: 4),
              for (final s in decimals)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${s.label}  ${num2(s.reading)} → ${num2(s.fix)}', style: bold),
                ),
            ],
            if (decimals.isNotEmpty && decreases.isNotEmpty) const SizedBox(height: 14),
            if (decreases.isNotEmpty) ...[
              const Text('지난달보다 작은 지침이 있습니다. 그대로 저장하면 계량기가 한 바퀴 돈 것으로 계산됩니다.'),
              const SizedBox(height: 4),
              for (final d in decreases)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.label}  ${num2(d.last)} → ${num2(d.reading)}  (사용량 ${num2(d.usage)})', style: bold),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, _DecimalChoice.asIs), child: const Text('그대로 저장')),
          if (decimals.isNotEmpty)
            FilledButton(onPressed: () => Navigator.pop(ctx, _DecimalChoice.fix), child: const Text('고쳐서 저장')),
        ],
      ),
    );
    if (choice == _DecimalChoice.fix) {
      for (final s in decimals) {
        s.controller.text = plainReading(s.fix);
      }
    }
    return choice != null;
  }

  /// 단일 호실 저장 — 저장 후 그 호실만 동기화하므로 다른 입력칸은 그대로 유지된다.
  Future<void> _save(Room room) async {
    final month = widget.month;
    if (!_ready) {
      showSnack(context, '이 달 검침을 불러온 뒤에 저장해주세요', error: true);
      return;
    }
    if (_parse(_water[room.roomId]) == null && _parse(_elec[room.roomId]) == null) {
      showSnack(context, '검침값을 입력해주세요', error: true);
      return;
    }
    final blanks = _blankFields(room);
    if (blanks.isNotEmpty) {
      showSnack(context, '${_meterName(room)}: ${blanks.join('·')} 지침이 비어 있습니다. 빈칸은 0으로 저장돼 사용량이 크게 잘못 계산됩니다.',
          error: true);
      return;
    }
    if (!await _confirmReadings([room]) || !mounted) return;
    try {
      await _persist(room, month);
      await _reloadMaps();
      _syncControllers([room.roomId]);
      if (mounted) {
        setState(() {});
        showSnack(context, '${_meterName(room)} 검침 저장 완료');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 입력된 모든 호실을 한 번에 저장(일괄 저장). 빈칸이 있는 계량기는 빼고 알려 준다.
  Future<void> _saveAll() async {
    final p = context.read<AppProvider>();
    final month = widget.month;
    if (!_ready) {
      showSnack(context, '이 달 검침을 불러온 뒤에 저장해주세요', error: true);
      return;
    }
    final entered = p.rooms
        .where((r) => _parse(_water[r.roomId]) != null || _parse(_elec[r.roomId]) != null)
        .toList();
    final blocked = <String>[];
    final targets = <Room>[];
    for (final r in entered) {
      final blanks = _blankFields(r);
      if (blanks.isEmpty) {
        targets.add(r);
      } else {
        blocked.add('${_meterName(r)}(${blanks.join('·')})');
      }
    }
    if (targets.isEmpty) {
      showSnack(context, blocked.isEmpty ? '입력된 검침값이 없습니다' : '빈칸이 있어 저장하지 않았습니다: ${blocked.join(', ')}',
          error: true);
      return;
    }
    if (!await _confirmReadings(targets) || !mounted) return;
    var ok = 0;
    final failed = <String>[];
    for (final r in targets) {
      try {
        await _persist(r, month);
        ok++;
      } catch (_) {
        failed.add(_meterName(r));
      }
    }
    await _reloadMaps();
    _syncControllers(targets.map((r) => r.roomId));
    if (mounted) {
      setState(() {});
      final notes = [
        if (failed.isNotEmpty) '실패: ${failed.join(', ')}',
        if (blocked.isNotEmpty) '빈칸이라 저장 안 함: ${blocked.join(', ')}',
      ];
      showSnack(
        context,
        notes.isEmpty ? '$ok개 계량기 일괄 저장 완료' : '$ok개 저장 · ${notes.join(' · ')}',
        error: notes.isNotEmpty,
      );
    }
  }

  /// 계량기 사진 촬영/선택 → AI OCR → 지침 필드 자동 입력 + 사진 보존(화면 확인용).
  Future<void> _pickAndRead(String type, int roomId, TextEditingController ctl, double? lastValue) async {
    final picked = await pickImageBase64(context, maxWidth: 1600);
    if (picked == null || !mounted) return;
    setState(() => _photos['$roomId-$type'] = BillPhoto(base64: picked.data, media: picked.media)); // 사진 남겨 비교
    final api = context.read<AppProvider>().api;
    try {
      final value = await api.readMeter(image: picked.data, type: type, lastValue: lastValue, mediaType: picked.media);
      if (!mounted) return;
      if (value != null) {
        ctl.text = num2(value);
        showSnack(context, '인식 완료: ${num2(value)} (사진과 비교해 확인하세요)');
      } else {
        showSnack(context, '계량기 숫자를 인식하지 못했습니다. 사진을 보고 직접 입력해주세요', error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final roomById = {for (final r in p.rooms) r.roomId: r};
    // 호실별로 계량기를 묶는다(호실 순서 = 서버 순서). 호실에 안 묶인 계량기는 맨 뒤 '기타'.
    final grouped = <(String, double?, List<Room>, bool)>[]; // (제목, 면적, 계량기, 호실에 안 묶인 것)
    final seen = <int>{};
    for (final u in p.units) {
      final rs = [for (final m in u.meters) if (roomById[m.roomId] != null) roomById[m.roomId]!];
      seen.addAll(rs.map((r) => r.roomId));
      if (rs.isNotEmpty) grouped.add((u.title, u.area, rs, false));
    }
    final rest = p.rooms.where((r) => !seen.contains(r.roomId)).toList();
    if (rest.isNotEmpty) grouped.add(('기타 계량기', null, rest, true));
    final total = p.rooms.length;
    final entered = p.rooms.where((r) => _byRoom.containsKey(r.roomId)).length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.md, BillySpace.gutter, BillySpace.xl),
            children: [
              ContentWidth(
                max: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('계량기 지침을 넣으면 지난달 대비 사용량이 바로 보입니다. 사진을 찍으면 AI 가 숫자를 읽어 줍니다.',
                        style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
                    const SizedBox(height: BillySpace.md),
                    if (_loading)
                      const LoadingView()
                    else if (_loadFailed)
                      ErrorBanner(message: '이 달 검침을 불러오지 못했습니다. 불러온 뒤에 입력·저장할 수 있습니다.', onRetry: _load)
                    else if (p.rooms.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyView(icon: Icons.meeting_room_outlined, message: '계량기가 없습니다.\n호실 탭에서 호실·계량기를 등록해주세요.'),
                      )
                    else
                      for (final g in grouped) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, BillySpace.md, 2, BillySpace.sm),
                          child: Row(
                            children: [
                              Expanded(child: Text(g.$1, style: BillyText.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (g.$2 != null) Text('${num2(g.$2)}㎡', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
                            ],
                          ),
                        ),
                        for (final r in g.$3)
                          _MeasureCard(
                            room: r,
                            // 호실 제목이 위에 있으니 계량기가 하나면 이름을 되풀이하지 않는다
                            title: g.$3.length > 1 || g.$4 ? _meterName(r) : null,
                            showNumber: g.$4,
                            info: _byRoom[r.roomId],
                            lastInfo: _lastByRoom[r.roomId],
                            last2Info: _last2ByRoom[r.roomId],
                            waterCtl: _ctl(_water, r.roomId),
                            elecCtl: _ctl(_elec, r.roomId),
                            waterPhoto: _photos['${r.roomId}-water'],
                            elecPhoto: _photos['${r.roomId}-electricity'],
                            onSave: () => _save(r),
                            onPickPhoto: _pickAndRead,
                          ),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
        StickyActionBar(
          leading: Text('저장된 계량기 $entered/$total', style: BillyText.captionStrong.copyWith(color: entered >= total && total > 0 ? BillyColors.success : BillyColors.textSecondary)),
          children: [
            SizedBox(height: 46, child: AsyncButton(label: '모두 저장', icon: Icons.save_alt_rounded, onPressed: () async => _saveAll())),
            SizedBox(
              height: 46,
              child: OutlinedButton(onPressed: widget.onNext, child: const Text('다음: 고지서')),
            ),
          ],
        ),
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  final Room room;
  final String? title; // 계량기 이름(같은 호실의 계량기 여럿을 구분). null 이면 안 보인다
  final bool showNumber; // 호실에 안 묶인 계량기만 호수를 따로 보여준다
  final BillInfo? info;
  final BillInfo? lastInfo;
  final BillInfo? last2Info;
  final TextEditingController waterCtl;
  final TextEditingController elecCtl;
  final BillPhoto? waterPhoto;
  final BillPhoto? elecPhoto;
  final VoidCallback onSave;
  final Future<void> Function(String type, int roomId, TextEditingController ctl, double? lastValue) onPickPhoto;

  const _MeasureCard({
    required this.room,
    required this.title,
    this.showNumber = false,
    required this.info,
    required this.lastInfo,
    required this.last2Info,
    required this.waterCtl,
    required this.elecCtl,
    required this.waterPhoto,
    required this.elecPhoto,
    required this.onSave,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final computed = info != null && (info!.waterUsage > 0 || info!.electricityUsage > 0);
    final header = title != null || showNumber || computed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header)
            Row(
              children: [
                if (showNumber) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                    child: Text('${room.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: title == null
                      ? const SizedBox()
                      : Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                if (computed) const BillyBadge('사용량 계산됨', color: BillyColors.success),
              ],
            ),
          if (lastInfo != null) ...[
            if (header) const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 13, color: BillyColors.textHint),
                  const SizedBox(width: 6),
                  Text('지난달 검침',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: BillyColors.textSecondary)),
                  const Spacer(),
                  _lastChip('수도', num2(lastInfo!.waterMeasure), BillyColors.water),
                  const SizedBox(width: 8),
                  _lastChip('전기', num2(lastInfo!.electricityMeasure), BillyColors.electricity),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final water = _MeasureField(
                label: '수도 지침',
                controller: waterCtl,
                color: BillyColors.water,
                fixedUsage: room.strictWater,
                lastMeasure: lastInfo?.waterMeasure,
                lastUsage: lastInfo?.waterUsage,
                last2Usage: last2Info?.waterUsage,
                fallbackUsage: info?.waterUsage,
                photo: waterPhoto,
                onPhoto: () => onPickPhoto('water', room.roomId, waterCtl, lastInfo?.waterMeasure),
              );
              final elec = _MeasureField(
                label: '전기 지침',
                controller: elecCtl,
                color: BillyColors.electricity,
                // 서버는 전기 사용량에 계량기 배수를 곱해 저장한다(지난달 사용량도 곱한 값)
                multiply: room.measureMultiply > 0 ? room.measureMultiply : 1,
                fixedUsage: room.strictElectricity,
                lastMeasure: lastInfo?.electricityMeasure,
                lastUsage: lastInfo?.electricityUsage,
                last2Usage: last2Info?.electricityUsage,
                fallbackUsage: info?.electricityUsage,
                photo: elecPhoto,
                onPhoto: () => onPickPhoto('electricity', room.roomId, elecCtl, lastInfo?.electricityMeasure),
              );
              // 좁은 화면(앱)에서는 세로로 쌓아 입력 편의 ↑
              if (c.maxWidth < 380) {
                return Column(children: [water, const SizedBox(height: 14), elec]);
              }
              return Row(children: [
                Expanded(child: water),
                const SizedBox(width: 12),
                Expanded(child: elec),
              ]);
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AsyncButton(label: '저장', icon: Icons.save_outlined, onPressed: () async => onSave()),
          ),
        ],
      ),
    );
  }

  Widget _lastChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: BillyColors.textPrimary)),
      ],
    );
  }
}

/// 사진 표시(S3 URL 또는 방금 촬영한 base64). w/h 미지정 시 원본 크기.
Widget _photoImage(BillPhoto photo, {double? w, double? h}) {
  if (photo.url != null) {
    return Image.network(photo.url!,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
              width: w,
              height: h ?? 64,
              color: BillyColors.surfaceAlt,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 18, color: BillyColors.textHint),
            ));
  }
  return Image.memory(base64Decode(photo.base64!), width: w, height: h, fit: BoxFit.cover);
}

/// 큰 사진 보기 다이얼로그(확대/이동 가능).
void _showPhotoDialog(BuildContext context, BillPhoto photo) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: BillyColors.photoBackdrop,
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(child: _photoImage(photo)),
    ),
  );
}

class _MeasureField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final double multiply; // 계량기 배수(사용량 = 지침 차 × 배수)
  final double fixedUsage; // 고정 사용량(호실 설정, 0 이면 없음) — 있으면 서버가 지침과 상관없이 이 값을 쓴다
  final double? lastMeasure; // 지난달 지침
  final double? lastUsage; // 지난달 사용량
  final double? last2Usage; // 지지난달 사용량
  final double? fallbackUsage; // 저장된 이번달 사용량(지침 비교 불가 시)
  final BillPhoto? photo;
  final Future<void> Function()? onPhoto;
  const _MeasureField({
    required this.label,
    required this.controller,
    required this.color,
    this.multiply = 1,
    this.fixedUsage = 0,
    this.lastMeasure,
    this.lastUsage,
    this.last2Usage,
    this.fallbackUsage,
    this.photo,
    this.onPhoto,
  });

  String _signed(double v) => '${v >= 0 ? '+' : ''}${num2(v)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            const Spacer(),
            if (onPhoto != null) _CamButton(color: color, onTap: onPhoto!),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '지침값', isDense: true),
        ),
        // 사용량·오차범위 힌트 (입력에 따라 실시간 갱신)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final reading = double.tryParse(value.text.replaceAll(',', '').trim());
            final thisUsage = (reading == null || lastMeasure == null)
                ? null
                : fixedUsage > 0
                    ? fixedUsage
                    : (reading - lastMeasure!) * multiply;
            final lastDelta = (lastUsage != null && last2Usage != null) ? lastUsage! - last2Usage! : null;
            final thisDelta = (thisUsage != null && lastUsage != null) ? thisUsage - lastUsage! : null;
            final warn = thisDelta != null && lastDelta != null && thisDelta.abs() > lastDelta.abs();
            final fix = suggestDecimalFix(reading, lastMeasure);

            final lines = <Widget>[];
            if (lastUsage != null && lastUsage! > 0) lines.add(_metric('지난달 사용량', num2(lastUsage)));
            if (thisUsage != null) {
              lines.add(_metric('이번달 사용량', num2(thisUsage),
                  strong: true, strongColor: thisUsage < 0 ? BillyColors.error : color));
            } else if (fallbackUsage != null && fallbackUsage! > 0) {
              lines.add(_metric('사용량', num2(fallbackUsage)));
            }
            if (lastDelta != null) lines.add(_metric('지난달 오차', _signed(lastDelta)));
            if (thisDelta != null) {
              lines.add(_metric('이번달 오차', _signed(thisDelta), strong: warn, strongColor: warn ? BillyColors.error : null));
            }
            if (lines.isEmpty && photo == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...lines,
                  if (thisUsage != null && thisUsage < 0) _warnBox('지침이 지난달보다 작습니다. 입력을 확인하세요'),
                  if (fix != null) ...[
                    _warnBox('지난달 지침보다 10배 넘게 큽니다. 소수점이 빠졌나요?'),
                    TextButton.icon(
                      onPressed: () => controller.text = plainReading(fix),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                      label: Text('${num2(fix)} 로 고치기'),
                      style: TextButton.styleFrom(
                        foregroundColor: BillyColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ] else if (warn)
                    _warnBox('이번달 변동폭이 지난달보다 큽니다. 확인 필요'),
                  if (photo != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showPhotoDialog(context, photo!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            _photoImage(photo!, h: 70, w: double.infinity),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration:
                                    BoxDecoration(color: BillyColors.scrim, borderRadius: BorderRadius.circular(6)),
                                child: const Text('탭하면 확대',
                                    style: TextStyle(color: BillyColors.onDark, fontSize: 9, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _metric(String label, String value, {bool strong = false, Color? strongColor}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text('$label ', style: const TextStyle(fontSize: 11, color: BillyColors.textHint)),
          Text(value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                color: strong ? (strongColor ?? BillyColors.textPrimary) : BillyColors.textSecondary,
              )),
        ],
      ),
    );
  }

  Widget _warnBox(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: BillyColors.errorSoft, borderRadius: BorderRadius.circular(7)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 13, color: BillyColors.error),
            const SizedBox(width: 4),
            Flexible(
                child: Text(msg,
                    style: const TextStyle(fontSize: 10.5, color: BillyColors.error, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

enum _DecimalChoice { fix, asIs }

/// 지난달보다 작은 지침 하나 — 그대로 저장하면 한 바퀴 돈 것으로 계산되는 사용량.
class _Decrease {
  final String label; // '고려신경-1 전기'
  final double last;
  final double reading;
  final double usage;
  const _Decrease(this.label, this.last, this.reading, this.usage);
}

/// 소수점이 빠진 것 같은 지침 하나 — 고칠 입력칸과 제안값.
class _DecimalSuspect {
  final String label; // '천리안안과-1 전기'
  final TextEditingController controller;
  final double reading;
  final double fix;
  const _DecimalSuspect(this.label, this.controller, this.reading, this.fix);
}

/// 계량기 사진 촬영 버튼(처리 중 스피너 표시).
class _CamButton extends StatefulWidget {
  final Color color;
  final Future<void> Function() onTap;
  const _CamButton({required this.color, required this.onTap});

  @override
  State<_CamButton> createState() => _CamButtonState();
}

class _CamButtonState extends State<_CamButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _busy ? null : _run,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: _busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: BillyColors.onDark))
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_rounded, size: 14, color: BillyColors.onDark),
                  SizedBox(width: 4),
                  Text('AI 촬영', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BillyColors.onDark)),
                ],
              ),
      ),
    );
  }
}
