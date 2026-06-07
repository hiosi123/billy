import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../models/floor.dart';
import '../../models/room.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class RoomsTab extends StatelessWidget {
  const RoomsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    return RefreshIndicator(
      onRefresh: () => p.loadDetail(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '층',
                  value: '${p.floors.length}',
                  icon: Icons.layers_outlined,
                  color: BillyColors.primary,
                  softColor: BillyColors.primarySoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: '호실',
                  value: '${p.rooms.length}',
                  icon: Icons.meeting_room_outlined,
                  color: BillyColors.water,
                  softColor: BillyColors.waterSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: '총 면적',
                  value: '${num2(p.floors.fold<double>(0, (s, f) => s + f.floorSpace))}㎡',
                  icon: Icons.straighten_outlined,
                  color: BillyColors.fee,
                  softColor: BillyColors.feeSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('층 / 호실', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _addFloor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('층 추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.floors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyView(icon: Icons.layers_clear_outlined, message: '등록된 층이 없습니다.\n먼저 층을 추가해주세요.'),
            )
          else
            ...(p.floors..sort((a, b) => a.floor.compareTo(b.floor))).map((f) => _FloorSection(floor: f)),
        ],
      ),
    );
  }

  void _addFloor(BuildContext context) {
    final p = context.read<AppProvider>();
    final floorCtl = TextEditingController();
    final spaceCtl = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('층 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: floorCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '층 (숫자)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: spaceCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '층 면적 (㎡)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final floor = int.tryParse(floorCtl.text);
              if (floor == null) {
                showSnack(context, '층 숫자를 입력해주세요', error: true);
                return;
              }
              Navigator.pop(context);
              try {
                await p.createFloor({
                  'floor': floor,
                  'floorSpace': double.tryParse(spaceCtl.text) ?? 0,
                  'buildingId': p.selectedBuilding!.buildingId,
                });
                if (context.mounted) showSnack(context, '층이 추가되었습니다');
              } catch (e) {
                if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _FloorSection extends StatelessWidget {
  final Floor floor;
  const _FloorSection({required this.floor});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final rooms = p.roomsOfFloor(floor.floorId)..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: '${floor.floor}층',
        icon: Icons.layers_rounded,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${num2(floor.floorSpace)}㎡',
                style: const TextStyle(fontSize: 12, color: BillyColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _addRoom(context, floor),
              icon: const Icon(Icons.add_circle_outline, size: 20, color: BillyColors.primary),
            ),
          ],
        ),
        child: rooms.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('호실 없음 — + 로 추가', style: TextStyle(color: BillyColors.textHint, fontSize: 13)),
              )
            : Column(
                children: [
                  for (int i = 0; i < rooms.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _RoomRow(room: rooms[i]),
                  ],
                ],
              ),
      ),
    );
  }

  void _addRoom(BuildContext context, Floor floor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomEditSheet(floor: floor),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final Room room;
  const _RoomRow({required this.room});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RoomEditSheet(room: room),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
              child: Text('${room.roomNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BillyColors.textPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${num2(room.roomSpace)}㎡ · 계량기 ${room.measureMachine}',
                      style: const TextStyle(fontSize: 11.5, color: BillyColors.textSecondary)),
                ],
              ),
            ),
            Text(won(room.roomBaseCost),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BillyColors.textPrimary)),
            const Icon(Icons.chevron_right_rounded, size: 18, color: BillyColors.textHint),
          ],
        ),
      ),
    );
  }
}

/// 호실 추가/수정 바텀시트.
class RoomEditSheet extends StatefulWidget {
  final Floor? floor; // 추가 모드
  final Room? room; // 수정 모드
  const RoomEditSheet({super.key, this.floor, this.room});

  @override
  State<RoomEditSheet> createState() => _RoomEditSheetState();
}

class _RoomEditSheetState extends State<RoomEditSheet> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _machine;
  late final TextEditingController _space;
  late final TextEditingController _baseCost;
  late final TextEditingController _strictWater;
  late final TextEditingController _strictElec;
  late final TextEditingController _multiply;

  bool get isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _number = TextEditingController(text: r?.roomNumber.toString() ?? '');
    _name = TextEditingController(text: r?.roomName ?? '');
    _machine = TextEditingController(text: r?.measureMachine ?? '');
    _space = TextEditingController(text: r != null ? num2(r.roomSpace) : '');
    _baseCost = TextEditingController(text: r != null ? r.roomBaseCost.toStringAsFixed(0) : '0');
    _strictWater = TextEditingController(text: r != null ? num2(r.strictWater) : '0');
    _strictElec = TextEditingController(text: r != null ? num2(r.strictElectricity) : '0');
    _multiply = TextEditingController(text: r != null ? num2(r.measureMultiply) : '1');
  }

  @override
  void dispose() {
    for (final c in [_number, _name, _machine, _space, _baseCost, _strictWater, _strictElec, _multiply]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppProvider>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BillyColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(isEdit ? '호실 수정' : '호실 추가', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (isEdit)
                    IconButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await p.deleteRoom(widget.room!.roomId);
                          if (context.mounted) showSnack(context, '호실이 삭제되었습니다');
                        } catch (e) {
                          if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: BillyColors.error),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '호실 번호'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: '호실 이름'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _machine, decoration: const InputDecoration(labelText: '계량기 명칭'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _space, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '면적 (㎡)'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _baseCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '기본요금(화재보험료 등) 원')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _multiply, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '계량기 배수'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _strictWater, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '고정 수도사용량'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _strictElec, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '고정 전기사용량 (0이면 미사용)')),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: AsyncButton(
                  label: isEdit ? '저장' : '추가하기',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    final number = int.tryParse(_number.text);
    if (number == null || _name.text.trim().isEmpty) {
      showSnack(context, '호실 번호와 이름을 입력해주세요', error: true);
      return;
    }
    final data = {
      'roomNumber': number,
      'roomName': _name.text.trim(),
      'measureMachine': _machine.text.trim(),
      'roomSpace': double.tryParse(_space.text) ?? 0,
      'roomBaseCost': double.tryParse(_baseCost.text) ?? 0,
      'strictWater': double.tryParse(_strictWater.text) ?? 0,
      'strictElectricity': double.tryParse(_strictElec.text) ?? 0,
      'measureMultiply': double.tryParse(_multiply.text) ?? 1,
    };
    try {
      if (isEdit) {
        await p.updateRoom(widget.room!.roomId, data);
      } else {
        await p.createRoom({
          ...data,
          'floorId': widget.floor!.floorId,
          'buildingId': p.selectedBuilding!.buildingId,
        });
      }
      if (context.mounted) {
        Navigator.pop(context);
        showSnack(context, isEdit ? '저장되었습니다' : '호실이 추가되었습니다');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }
}
