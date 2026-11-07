import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 건물 정보 — 이름·주소·층수·엘리베이터·소유자.
class BuildingInfoScreen extends StatefulWidget {
  const BuildingInfoScreen({super.key});

  @override
  State<BuildingInfoScreen> createState() => _BuildingInfoScreenState();
}

class _BuildingInfoScreenState extends State<BuildingInfoScreen> {
  late final b = context.read<AppProvider>().building!;
  late final _name = TextEditingController(text: b.buildingName);
  late final _address = TextEditingController(text: b.buildingAddress);
  late final _floors = TextEditingController(text: '${b.buildingFloors}');
  late final _owner = TextEditingController(text: b.owner);
  late bool _elevator = b.elevator > 0;

  @override
  void dispose() {
    for (final c in [_name, _address, _floors, _owner]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, '건물 이름을 입력해주세요', error: true);
      return;
    }
    try {
      await context.read<AppProvider>().updateBuildingInfo({
        'buildingName': _name.text.trim(),
        'buildingAddress': _address.text.trim(),
        'buildingFloors': int.tryParse(_floors.text.trim()) ?? b.buildingFloors,
        'elevator': _elevator ? 1 : 0,
        'owner': _owner.text.trim(),
      });
      if (mounted) showSnack(context, '건물 정보를 저장했습니다');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildingAppBar(context, '건물 정보', back: '/b/${context.read<AppProvider>().buildingId}/settings'),
      body: ListView(
        padding: const EdgeInsets.all(BillySpace.gutter),
        children: [
          ContentWidth(
            max: 640,
            child: BillyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: _name, decoration: const InputDecoration(labelText: '건물 이름')),
                  const SizedBox(height: BillySpace.md),
                  TextField(controller: _address, decoration: const InputDecoration(labelText: '주소')),
                  const SizedBox(height: BillySpace.md),
                  Row(children: [
                    Expanded(child: TextField(controller: _floors, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '층수'))),
                    const SizedBox(width: BillySpace.md),
                    Expanded(child: TextField(controller: _owner, decoration: const InputDecoration(labelText: '소유자'))),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('엘리베이터 있음'),
                    value: _elevator,
                    onChanged: (v) => setState(() => _elevator = v),
                  ),
                  const SizedBox(height: BillySpace.sm),
                  SizedBox(height: 48, child: AsyncButton(label: '저장', icon: Icons.save_rounded, onPressed: _save)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
