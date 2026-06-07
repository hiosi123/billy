import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/bill.dart';
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
  Map<int, BillInfo> _lastByRoom = {}; // roomId -> 지난달 청구(검침값 표시용)
  final Map<int, TextEditingController> _water = {};
  final Map<int, TextEditingController> _elec = {};

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
      final results = await Future.wait([
        p.api.getBillsByCondition(month: p.chargeMonth, buildingId: buildingId),
        p.api.getBillsByCondition(month: _prevMonth(p.chargeMonth), buildingId: buildingId),
      ]);
      _byRoom = {for (final i in results[0]) i.roomId: i};
      _lastByRoom = {for (final i in results[1]) i.roomId: i};
      for (final r in p.rooms) {
        final info = _byRoom[r.roomId];
        final wc = _water.putIfAbsent(r.roomId, () => TextEditingController());
        wc.text = info != null && info.waterMeasure > 0 ? num2(info.waterMeasure) : '';
        final ec = _elec.putIfAbsent(r.roomId, () => TextEditingController());
        ec.text = info != null && info.electricityMeasure > 0 ? num2(info.electricityMeasure) : '';
      }
    } catch (_) {
      _byRoom = {};
      _lastByRoom = {};
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(Room room) async {
    final p = context.read<AppProvider>();
    final water = double.tryParse(_water[room.roomId]?.text ?? '');
    final elec = double.tryParse(_elec[room.roomId]?.text ?? '');
    if (water == null && elec == null) {
      showSnack(context, '검침값을 입력해주세요', error: true);
      return;
    }
    try {
      await p.api.insertMeasure({
        'BuildingId': room.buildingId,
        'FloorId': room.floorId,
        'RoomId': room.roomId,
        'WaterMeasure': water ?? 0,
        'ElectricityMeasure': elec ?? 0,
        'ChargeMonth': p.chargeMonth,
      });
      if (mounted) showSnack(context, '${room.roomName} 검침 저장 완료');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 계량기 사진 촬영/선택 → AI OCR → 지침 필드 자동 입력. (type: 'water'|'electricity')
  Future<void> _pickAndRead(String type, TextEditingController ctl, double? lastValue) async {
    final picked = await pickImageBase64(context, maxWidth: 1600);
    if (picked == null || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final value = await api.readMeter(image: picked.data, type: type, lastValue: lastValue, mediaType: picked.media);
      if (!mounted) return;
      if (value != null) {
        ctl.text = num2(value);
        showSnack(context, '인식 완료: ${num2(value)}');
      } else {
        showSnack(context, '계량기 숫자를 인식하지 못했습니다. 직접 입력해주세요', error: true);
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
                waterCtl: _water[r.roomId]!,
                elecCtl: _elec[r.roomId]!,
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
  final TextEditingController waterCtl;
  final TextEditingController elecCtl;
  final VoidCallback onSave;
  final Future<void> Function(String type, TextEditingController ctl, double? lastValue) onPickPhoto;

  const _MeasureCard({
    required this.room,
    required this.info,
    required this.lastInfo,
    required this.waterCtl,
    required this.elecCtl,
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
                usage: info?.waterUsage,
                onPhoto: () => onPickPhoto('water', waterCtl, lastInfo?.waterMeasure),
              );
              final elec = _MeasureField(
                label: '전기 지침',
                controller: elecCtl,
                color: BillyColors.electricity,
                usage: info?.electricityUsage,
                onPhoto: () => onPickPhoto('electricity', elecCtl, lastInfo?.electricityMeasure),
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

class _MeasureField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final double? usage;
  final Future<void> Function()? onPhoto;
  const _MeasureField({
    required this.label,
    required this.controller,
    required this.color,
    this.usage,
    this.onPhoto,
  });

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
        if (usage != null && usage! > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('사용량 ${num2(usage)}', style: const TextStyle(fontSize: 11, color: BillyColors.textSecondary)),
          ),
      ],
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
