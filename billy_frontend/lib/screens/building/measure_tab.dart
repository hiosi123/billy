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
import '../../widgets/common.dart';
import 'month_selector.dart';

class MeasureTab extends StatefulWidget {
  const MeasureTab({super.key});

  @override
  State<MeasureTab> createState() => _MeasureTabState();
}

class _MeasureTabState extends State<MeasureTab> {
  bool _loading = false;
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
  void dispose() {
    for (final c in _water.values) {
      c.dispose();
    }
    for (final c in _elec.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    setState(() => _loading = true);
    try {
      final buildingId = p.selectedBuilding!.buildingId;
      final prev1 = _prevMonth(p.chargeMonth);
      final prev2 = _prevMonth(prev1);
      final results = await Future.wait([
        p.api.getBillsByCondition(month: p.chargeMonth, buildingId: buildingId),
        p.api.getBillsByCondition(month: prev1, buildingId: buildingId),
        p.api.getBillsByCondition(month: prev2, buildingId: buildingId),
      ]);
      _byRoom = {for (final i in results[0]) i.roomId: i};
      _lastByRoom = {for (final i in results[1]) i.roomId: i};
      _last2ByRoom = {for (final i in results[2]) i.roomId: i};
      _photos.clear();
      for (final r in p.rooms) {
        final info = _byRoom[r.roomId];
        final wc = _water.putIfAbsent(r.roomId, () => TextEditingController());
        wc.text = info != null && info.waterMeasure > 0 ? num2(info.waterMeasure) : '';
        final ec = _elec.putIfAbsent(r.roomId, () => TextEditingController());
        ec.text = info != null && info.electricityMeasure > 0 ? num2(info.electricityMeasure) : '';
        // 저장돼 있던 계량기 사진(S3 URL) 복원
        if (info?.waterMeterPhoto != null) _photos['${r.roomId}-water'] = BillPhoto(url: info!.waterMeterPhoto);
        if (info?.electricityMeterPhoto != null) {
          _photos['${r.roomId}-electricity'] = BillPhoto(url: info!.electricityMeterPhoto);
        }
      }
    } catch (_) {
      _byRoom = {};
      _lastByRoom = {};
      _last2ByRoom = {};
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 콤마가 섞여 있어도 안전하게 파싱(빈칸이면 null).
  double? _parse(TextEditingController? c) {
    final t = c?.text.replaceAll(',', '').trim() ?? '';
    return t.isEmpty ? null : double.tryParse(t);
  }

  /// 이번달/지난달 청구 맵만 다시 불러온다(입력 컨트롤러는 건드리지 않음).
  Future<void> _reloadMaps() async {
    final p = context.read<AppProvider>();
    final buildingId = p.selectedBuilding!.buildingId;
    final prev1 = _prevMonth(p.chargeMonth);
    final prev2 = _prevMonth(prev1);
    final results = await Future.wait([
      p.api.getBillsByCondition(month: p.chargeMonth, buildingId: buildingId),
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

  Future<void> _persist(Room room) async {
    final p = context.read<AppProvider>();
    final api = p.api;
    final waterUrl = await _uploadIfNeeded(api, '${room.roomId}-water');
    final elecUrl = await _uploadIfNeeded(api, '${room.roomId}-electricity');
    await api.insertMeasure({
      'BuildingId': room.buildingId,
      'FloorId': room.floorId,
      'RoomId': room.roomId,
      'WaterMeasure': _parse(_water[room.roomId]) ?? 0,
      'ElectricityMeasure': _parse(_elec[room.roomId]) ?? 0,
      'ChargeMonth': p.chargeMonth,
      'WaterMeterPhoto': waterUrl,
      'ElectricityMeterPhoto': elecUrl,
    });
  }

  /// 단일 호실 저장 — 저장 후 그 호실만 동기화하므로 다른 입력칸은 그대로 유지된다.
  Future<void> _save(Room room) async {
    if (_parse(_water[room.roomId]) == null && _parse(_elec[room.roomId]) == null) {
      showSnack(context, '검침값을 입력해주세요', error: true);
      return;
    }
    try {
      await _persist(room);
      await _reloadMaps();
      _syncControllers([room.roomId]);
      if (mounted) {
        setState(() {});
        showSnack(context, '${room.roomName} 검침 저장 완료');
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 입력된 모든 호실을 한 번에 저장(일괄 저장).
  Future<void> _saveAll() async {
    final p = context.read<AppProvider>();
    final targets = p.rooms
        .where((r) => _parse(_water[r.roomId]) != null || _parse(_elec[r.roomId]) != null)
        .toList();
    if (targets.isEmpty) {
      showSnack(context, '입력된 검침값이 없습니다', error: true);
      return;
    }
    var ok = 0;
    final failed = <String>[];
    for (final r in targets) {
      try {
        await _persist(r);
        ok++;
      } catch (_) {
        failed.add(r.roomName);
      }
    }
    await _reloadMaps();
    _syncControllers(targets.map((r) => r.roomId));
    if (mounted) {
      setState(() {});
      showSnack(
        context,
        failed.isEmpty ? '$ok개 호실 일괄 저장 완료' : '$ok개 저장 · 실패: ${failed.join(', ')}',
        error: failed.isNotEmpty,
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
    final rooms = [...p.rooms]..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        MonthSelector(
          month: p.chargeMonth,
          onChanged: (m) {
            p.setChargeMonth(m);
            _load();
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BillyColors.primarySoft, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: BillyColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '계량기 지침값을 입력하면 지난달 대비 사용량이 자동 계산됩니다. (지난달 데이터가 있어야 합니다)',
                  style: TextStyle(fontSize: 12, color: BillyColors.primaryDark, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (rooms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: AsyncButton(
                label: '전체 호실 일괄 저장',
                icon: Icons.save_alt_rounded,
                onPressed: () async => _saveAll(),
              ),
            ),
          ),
        if (_loading && _byRoom.isEmpty)
          const LoadingView()
        else if (rooms.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyView(icon: Icons.meeting_room_outlined, message: '호실이 없습니다.\n먼저 호실을 등록해주세요.'),
          )
        else
          ...rooms.map((r) => _MeasureCard(
                room: r,
                info: _byRoom[r.roomId],
                lastInfo: _lastByRoom[r.roomId],
                last2Info: _last2ByRoom[r.roomId],
                waterCtl: _water[r.roomId]!,
                elecCtl: _elec[r.roomId]!,
                waterPhoto: _photos['${r.roomId}-water'],
                elecPhoto: _photos['${r.roomId}-electricity'],
                onSave: () => _save(r),
                onPickPhoto: _pickAndRead,
              )),
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  final Room room;
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
                child: Text('${room.roomNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(room.roomName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (info != null && (info!.waterUsage > 0 || info!.electricityUsage > 0))
                const BillyBadge('사용량 계산됨', color: BillyColors.success),
            ],
          ),
          if (lastInfo != null) ...[
            const SizedBox(height: 10),
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
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: InteractiveViewer(child: _photoImage(photo)),
    ),
  );
}

class _MeasureField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
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
            final thisUsage = (reading != null && lastMeasure != null) ? reading - lastMeasure! : null;
            final lastDelta = (lastUsage != null && last2Usage != null) ? lastUsage! - last2Usage! : null;
            final thisDelta = (thisUsage != null && lastUsage != null) ? thisUsage - lastUsage! : null;
            final warn = thisDelta != null && lastDelta != null && thisDelta.abs() > lastDelta.abs();

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
                  if (warn) _warnBox('이번달 변동폭이 지난달보다 큽니다. 확인 필요'),
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
                                    BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                child: const Text('탭하면 확대',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
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
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(7)),
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
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('AI 촬영', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}
