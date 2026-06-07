import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class FeeSettingsTab extends StatefulWidget {
  const FeeSettingsTab({super.key});

  @override
  State<FeeSettingsTab> createState() => _FeeSettingsTabState();
}

class _FeeSettingsTabState extends State<FeeSettingsTab> {
  late final Map<String, TextEditingController> _c;

  static const _fields = <String, String>{
    'generalManagementFee': '일반관리비',
    'publicInspectionFee': '공동검침비',
    'fireManagementFee': '소방관리비',
    'elevatorMaintenanceFee': '승강기유지비',
    'septicTankManagementFee': '정화조관리비',
    'electricalManagementFee': '전기안전관리비',
    'parkingManagementFee': '주차관리비',
  };

  @override
  void initState() {
    super.initState();
    final fee = context.read<AppProvider>().fee;
    final map = {
      'generalManagementFee': fee.generalManagementFee,
      'publicInspectionFee': fee.publicInspectionFee,
      'fireManagementFee': fee.fireManagementFee,
      'elevatorMaintenanceFee': fee.elevatorMaintenanceFee,
      'septicTankManagementFee': fee.septicTankManagementFee,
      'electricalManagementFee': fee.electricalManagementFee,
      'parkingManagementFee': fee.parkingManagementFee,
    };
    _c = {for (final k in _fields.keys) k: TextEditingController(text: map[k]! > 0 ? map[k]!.toStringAsFixed(0) : '')};
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _total => _c.values.fold<double>(0, (s, c) => s + (double.tryParse(c.text) ?? 0));

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    final data = <String, dynamic>{'buildingId': p.selectedBuilding!.buildingId};
    for (final k in _fields.keys) {
      data[k] = double.tryParse(_c[k]!.text) ?? 0;
    }
    try {
      await p.saveFee(data);
      if (mounted) showSnack(context, '관리비 설정이 저장되었습니다');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: BillyColors.feeSoft, borderRadius: BorderRadius.circular(10)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: BillyColors.fee),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '건물 전체의 고정 관리비입니다. 명세서 생성 시 호실 면적 비율로 자동 안분됩니다.',
                  style: TextStyle(fontSize: 12, color: BillyColors.fee, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: '고정 관리비 항목',
          icon: Icons.tune_rounded,
          child: Column(
            children: [
              for (final entry in _fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(entry.value,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: BillyColors.textPrimary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _c[entry.key],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(hintText: '0', suffixText: '원', isDense: true),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 8),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: BillyColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Text('합계', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    Text(won(_total),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: BillyColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: AsyncButton(label: '저장', icon: Icons.save_rounded, onPressed: _save),
        ),
      ],
    );
  }
}
