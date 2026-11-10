import 'package:flutter/material.dart';
import '../../utils/format.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app/shell.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 명세서 설정 — 예전엔 엑셀 양식에 박혀 있던 문구(관리소장·납부 장소·공지·검침일·연체율)를 여기서 고친다.
class StatementSettingsScreen extends StatefulWidget {
  const StatementSettingsScreen({super.key});

  @override
  State<StatementSettingsScreen> createState() => _StatementSettingsScreenState();
}

class _StatementSettingsScreenState extends State<StatementSettingsScreen> {
  StatementSettingsV2? _s;
  Object? _error;
  final _manager = TextEditingController();
  final _place = TextEditingController();
  final _bank = TextEditingController();
  final _notice = TextEditingController();
  final _meterDay = TextEditingController();
  final _dueDay = TextEditingController();
  final _late = TextEditingController();
  int _truncate = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_manager, _place, _bank, _notice, _meterDay, _dueDay, _late]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    setState(() => _error = null);
    try {
      final s = await p.api.getStatementSettings(p.buildingId!);
      if (!mounted) return;
      setState(() {
        _s = s;
        _manager.text = s.managerTitle;
        _place.text = s.payPlace;
        _bank.text = s.bankAccount;
        _notice.text = s.notice;
        _meterDay.text = '${s.meterDay}';
        _dueDay.text = s.dueDay?.toString() ?? '';
        // 1.25% 가 '1.3' 으로 반올림돼 다음 저장 때 1.3% 로 바뀌었다 — 있는 그대로(최대 소수 둘째 자리)
        _late.text = num2(s.lateFeeRate * 100);
        _truncate = s.truncateUnit;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    final s = _s!;
    final meterDay = int.tryParse(_meterDay.text.trim());
    final dueDay = _dueDay.text.trim().isEmpty ? null : int.tryParse(_dueDay.text.trim());
    final lateText = _late.text.replaceAll('%', '').replaceAll(',', '.').trim();
    final late = double.tryParse(lateText.isEmpty ? '0' : lateText);
    if (meterDay == null || meterDay < 1 || meterDay > 31 || (dueDay != null && (dueDay < 1 || dueDay > 31)) || late == null) {
      showSnack(context, '검침일·납기일은 1~31, 연체율은 숫자로 넣어 주세요', error: true);
      return;
    }
    s
      ..managerTitle = _manager.text.trim()
      ..payPlace = _place.text.trim()
      ..bankAccount = _bank.text.trim()
      ..notice = _notice.text
      ..meterDay = meterDay
      ..dueDay = dueDay
      ..lateFeeRate = late / 100
      ..truncateUnit = _truncate;
    try {
      final saved = await p.api.saveStatementSettings(p.buildingId!, s);
      if (!mounted) return;
      // 서버가 정리한 값(길이 자르기 등)을 칸에도 보인다
      setState(() {
        _s = saved;
        _manager.text = saved.managerTitle;
        _place.text = saved.payPlace;
        _bank.text = saved.bankAccount;
        _notice.text = saved.notice;
        _dueDay.text = saved.dueDay?.toString() ?? '';
        _late.text = num2(saved.lateFeeRate * 100);
      });
      showSnack(context, '명세서 설정을 저장했습니다 — 다음에 내려받는 엑셀부터 반영됩니다');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildingAppBar(context, '명세서', back: '/b/${context.read<AppProvider>().buildingId}/settings'),
      body: ListView(
        padding: const EdgeInsets.all(BillySpace.gutter),
        children: [
          ContentWidth(
            max: 720,
            child: _error != null
                ? ErrorBanner(message: '설정을 불러오지 못했습니다: ${errorText(_error!)}', onRetry: _load)
                : _s == null
                    ? const LoadingView()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BillyCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              TextField(controller: _manager, inputFormatters: [LengthLimitingTextInputFormatter(60)], decoration: const InputDecoration(labelText: '명세서 아래 서명', hintText: '○○빌딩 관리사무소')),
                              const SizedBox(height: BillySpace.md),
                              TextField(controller: _place, inputFormatters: [LengthLimitingTextInputFormatter(80)], decoration: const InputDecoration(labelText: '납부 장소', hintText: '○○은행 또는 ○○우체국')),
                              const SizedBox(height: BillySpace.md),
                              TextField(controller: _bank, inputFormatters: [LengthLimitingTextInputFormatter(80)], decoration: const InputDecoration(labelText: '입금 계좌', hintText: '은행 계좌번호 (예금주)')),
                            ]),
                          ),
                          const SectionTitle('공지 문구', subtitle: '명세서 공지사항 칸. (lMonth)·(fDate)·(lDate) 를 쓰면 그달 날짜로 바뀝니다'),
                          BillyCard(
                            child: TextField(controller: _notice, maxLines: 5, minLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: '입점주 여러분께 알리는 말')),
                          ),
                          const SectionTitle('날짜·연체'),
                          BillyCard(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Expanded(child: TextField(controller: _meterDay, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '검침일', suffixText: '일'))),
                                const SizedBox(width: BillySpace.md),
                                Expanded(
                                  child: TextField(
                                    controller: _dueDay,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: '납기일', suffixText: '일', helperText: '비우면 고지월 말일'),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: BillySpace.md),
                              TextField(controller: _late, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '연체율', suffixText: '%')),
                              const SizedBox(height: BillySpace.md),
                              Text('금액 끝자리', style: BillyText.captionStrong),
                              const SizedBox(height: BillySpace.xs),
                              Wrap(spacing: BillySpace.xs, children: [
                                for (final u in const [1, 10, 100])
                                  ChoiceChip(
                                    label: Text(u == 1 ? '원 단위 그대로' : '$u원 아래 버림'),
                                    selected: _truncate == u,
                                    onSelected: (_) => setState(() => _truncate = u),
                                  ),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: BillySpace.lg),
                          SizedBox(height: 48, child: AsyncButton(label: '저장', icon: Icons.save_rounded, onPressed: _save)),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
