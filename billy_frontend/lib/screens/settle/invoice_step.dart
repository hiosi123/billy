import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_photo.dart';
import '../../models/plan.dart';
import '../../models/v2.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/image_pick.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';
import 'settle_screen.dart' show SettleDraft;

/// 정산 2단계 — 고지서 금액. 요금표가 요구하는 칸만 나온다(항목을 바꾸면 칸도 바뀐다).
/// 고지서 사진을 올리면 AI 가 금액을 읽어 채우고, 사진은 그달에 보관된다.
class InvoiceStep extends StatefulWidget {
  final String month;
  final VoidCallback onNext;
  const InvoiceStep({super.key, required this.month, required this.onNext});

  @override
  State<InvoiceStep> createState() => _InvoiceStepState();
}

class _Field {
  final String key;
  final String label;
  final String unit;
  final TextEditingController ctl = TextEditingController();
  String saved = ''; // 불러온(저장된) 글 — 지금 글과 다르면 '고친 것'
  _Field(this.key, this.label, this.unit);
}

class _DirectSection {
  final PlanItem item;
  final List<(UnitV2, _Field)> rows;
  _DirectSection(this.item, this.rows);
}

class _InvoiceStepState extends State<InvoiceStep> {
  bool _loading = true;
  Object? _error;
  int _seq = 0;
  List<_Field> _fields = [];
  List<_DirectSection> _direct = [];
  BillPhoto? _waterPhoto;
  final List<BillPhoto> _elecPhotos = [];
  /// 고친 게 있나 — 칸 글이 저장된 값과 다르거나, 찍은 고지서 사진이 아직 안 올라갔다.
  /// (예전엔 칸을 누르기만 해도 '고침'이 돼 빈 달에 0이 저장되고 '입력됨'으로 보였다)
  bool get _dirty =>
      _allFields.any((f) => f.ctl.text != f.saved) || _waterPhoto?.base64 != null || _elecPhotos.any((ph) => ph.base64 != null);

  void _markSaved() {
    for (final f in _allFields) {
      f.saved = f.ctl.text;
    }
  }

  @override
  void initState() {
    super.initState();
    SettleDraft.claim(
      this,
      pending: () => _dirty && !_loading && _error == null ? '고지서 금액' : null,
      save: () => _save(quiet: true),
      discard: () {
        for (final f in _allFields) {
          f.ctl.text = f.saved;
        }
        _waterPhoto = _waterPhoto?.base64 != null ? null : _waterPhoto;
        _elecPhotos.removeWhere((ph) => ph.base64 != null);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant InvoiceStep old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _load();
  }

  @override
  void dispose() {
    SettleDraft.release(this);
    for (final f in _allFields) {
      f.ctl.dispose();
    }
    super.dispose();
  }

  Iterable<_Field> get _allFields => [..._fields, for (final d in _direct) ...d.rows.map((r) => r.$2)];

  Future<void> _load() async {
    final p = context.read<AppProvider>();
    final bid = p.buildingId!;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = (await p.api.getPlan(bid, widget.month)).plan;
      final inputs = await p.api.getMonthInputs(bid, widget.month);
      if (!mounted || seq != _seq) return;
      final fields = <_Field>[];
      void add(String? key, String fallbackLabel) {
        if (key == null || key.isEmpty || fields.any((f) => f.key == key)) return;
        final std = inputLabels[key];
        fields.add(_Field(key, std?.$1 ?? fallbackLabel, std?.$2 ?? '원'));
      }

      for (final item in plan.items) {
        add(item.cost?.input, '${item.label} 금액');
        for (final k in item.cost?.minusInputs ?? const <String>[]) {
          add(k, k);
        }
        if (item.usageInput != null) {
          final std = inputLabels[item.usageInput!];
          if (!fields.any((f) => f.key == item.usageInput)) {
            fields.add(_Field(item.usageInput!, std?.$1 ?? '${item.label} 총 사용량', std?.$2 ?? (item.utility == 'water' ? 'm³' : 'kWh')));
          }
        }
      }
      // 수도 사용량은 계산엔 안 쓰여도 검산(호실 합계 vs 고지서)에 쓴다 — 수도 항목이 있으면 같이 받는다.
      if (plan.items.any((i) => i.utility == 'water') && !fields.any((f) => f.key == 'W_USAGE')) {
        fields.add(_Field('W_USAGE', '전체 수도 사용량', 'm³'));
      }
      final direct = <_DirectSection>[];
      for (final item in plan.items.where((i) => i.method == ChargeMethod.direct)) {
        final key = item.directKey ?? item.code;
        final units = p.units.where((u) {
          if (item.scopeOnly.isNotEmpty && !item.scopeOnly.contains(u.unitNumber)) return false;
          return !item.scopeExclude.contains(u.unitNumber);
        });
        direct.add(_DirectSection(item, [for (final u in units) (u, _Field('$key:${u.unitNumber}', u.title, '원'))]));
      }
      for (final f in [...fields, for (final d in direct) ...d.rows.map((r) => r.$2)]) {
        final v = inputs.values[f.key];
        f.ctl.text = v == null || v == 0 ? '' : (f.unit == '원' ? money(v) : num2(v));
        f.saved = f.ctl.text;
      }
      for (final f in _allFields) {
        f.ctl.dispose();
      }
      setState(() {
        _fields = fields;
        _direct = direct;
        _waterPhoto = (inputs.waterPhoto?.isNotEmpty ?? false) ? BillPhoto.fromStored(inputs.waterPhoto!) : null;
        _elecPhotos
          ..clear()
          ..addAll(inputs.elecPhotos.where((s) => s.isNotEmpty).map(BillPhoto.fromStored));
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  double? _parse(TextEditingController c) {
    final t = c.text.replaceAll(',', '').trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<String?> _upload(ApiService api, BillPhoto? photo) async {
    if (photo == null) return null;
    if (photo.url != null) return photo.url;
    if (photo.base64 == null) return null;
    return api.uploadImage('bill', photo.media, base64Decode(photo.base64!));
  }

  /// 저장했으면 true. 입력이 틀렸거나 서버가 거절하면 알리고 false(다음 단계로 넘어가지 않게).
  Future<bool> _save({bool quiet = false}) async {
    if (_loading || _error != null) {
      showSnack(context, '이 달 입력값을 불러온 뒤에 저장해주세요', error: true);
      return false;
    }
    final p = context.read<AppProvider>();
    final bad = _allFields.where((f) => f.ctl.text.trim().isNotEmpty && _parse(f.ctl) == null).map((f) => f.label).toList();
    if (bad.isNotEmpty) {
      showSnack(context, '숫자가 아닌 칸: ${bad.join(', ')}', error: true);
      return false;
    }
    final values = {for (final f in _allFields) f.key: _parse(f.ctl) ?? 0.0};
    try {
      final waterUrl = await _upload(p.api, _waterPhoto);
      final elecUrls = <String>[];
      for (final ph in _elecPhotos) {
        final u = await _upload(p.api, ph);
        if (u != null) elecUrls.add(u);
      }
      await p.api.saveMonthInputs(p.buildingId!, widget.month, values, waterPhoto: waterUrl, elecPhotos: elecUrls);
      _markSaved();
      if (!mounted) return true;
      setState(() {
        if (waterUrl != null) _waterPhoto = BillPhoto(url: waterUrl);
        _elecPhotos
          ..clear()
          ..addAll(elecUrls.map((u) => BillPhoto(url: u)));
      });
      if (!quiet) showSnack(context, '${shortMonth(widget.month)} 고지서 금액을 저장했습니다');
      return true;
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
      return false;
    }
  }

  /// 예전엔 입력이 틀려 저장이 안 돼도 다음 단계로 넘어가 고친 금액이 사라졌다.
  Future<void> _saveAndNext() async {
    if (_dirty && !await _save(quiet: true)) return;
    widget.onNext();
  }

  // ── 고지서 사진 → AI 인식(기존 API) ──
  int _fill(Map r, Map<String, String> mapping) {
    var n = 0;
    for (final e in mapping.entries) {
      final v = r[e.key];
      final f = _fields.where((x) => x.key == e.value).firstOrNull;
      if (f != null && v is num) {
        f.ctl.text = f.unit == '원' ? money(v) : num2(v);
        n++;
      }
    }
    return n;
  }

  static const _waterMap = {'waterTotalUsage': 'W_USAGE', 'waterSupplyCost': 'W_SUPPLY', 'waterSewerCost': 'W_SEWER', 'waterTotalCost': 'W_TOTAL'};
  static const _elecMap = {'electricityTotalCost': 'E_COST', 'electricityTotalUsage': 'E_USAGE'};

  Future<void> _readWater() async {
    ({String data, String media})? got;
    try {
      got = await pickImageBase64(context, maxWidth: 2400);
    } catch (_) {
      if (mounted) showSnack(context, '사진을 가져오지 못했습니다. 카메라·사진 권한을 확인해 주세요', error: true);
      return;
    }
    final picked = got;
    if (picked == null || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final r = await api.readBill(image: picked.data, type: 'water', mediaType: picked.media);
      if (!mounted) return;
      final n = _fill(r, _waterMap);
      setState(() => _waterPhoto = BillPhoto(base64: picked.data, media: picked.media));
      showSnack(context, n > 0 ? '수도 고지서에서 $n개 항목을 읽었습니다 (사진과 비교해 확인)' : '수도 고지서에서 값을 읽지 못했습니다', error: n == 0);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _readElec() async {
    final List<({String data, String media})> images;
    try {
      images = await pickImagesBase64(maxWidth: 2400);
    } catch (_) {
      if (mounted) showSnack(context, '사진을 가져오지 못했습니다. 카메라·사진 권한을 확인해 주세요', error: true);
      return;
    }
    if (images.isEmpty || !mounted) return;
    final p = context.read<AppProvider>();
    try {
      final r = await p.api.readBillElec(images: images.map((e) => e.data).toList(), mediaType: images.first.media, buildingId: p.buildingId, chargeMonth: widget.month);
      if (!mounted) return;
      final n = _fill(r, _elecMap);
      setState(() => _elecPhotos
        ..clear()
        ..addAll(images.map((e) => BillPhoto(base64: e.data, media: e.media))));
      showSnack(context, n > 0 ? '전기 고지서 ${images.length}장에서 $n개 항목을 읽었습니다 (사진과 비교해 확인)' : '전기 고지서에서 값을 읽지 못했습니다', error: n == 0);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasElec = _fields.any((f) => f.key.startsWith('E_'));
    final hasWater = _fields.any((f) => f.key.startsWith('W_'));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.md, BillySpace.gutter, BillySpace.xl),
            children: [
              ContentWidth(
                max: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const LoadingView()
                    else if (_error != null)
                      ErrorBanner(message: '이 달 입력값을 불러오지 못했습니다: ${errorText(_error!)}', onRetry: _load)
                    else ...[
                      if (hasElec || hasWater)
                        BillyCard(
                          color: BillyColors.primarySoft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                const Icon(Icons.auto_awesome_rounded, size: 18, color: BillyColors.primary),
                                const SizedBox(width: BillySpace.sm),
                                Expanded(child: Text(keepAll('고지서 사진을 올리면 AI 가 금액을 읽어 채웁니다'), style: BillyText.captionStrong.copyWith(color: BillyColors.primaryDark))),
                              ]),
                              const SizedBox(height: BillySpace.md),
                              Wrap(
                                spacing: BillySpace.sm,
                                runSpacing: BillySpace.sm,
                                children: [
                                  if (hasElec)
                                    SizedBox(height: 44, child: AsyncButton(label: '전기 고지서', icon: Icons.photo_camera_rounded, color: BillyColors.electricity, onPressed: _readElec)),
                                  if (hasWater)
                                    SizedBox(height: 44, child: AsyncButton(label: '수도 고지서', icon: Icons.photo_camera_rounded, color: BillyColors.water, onPressed: _readWater)),
                                ],
                              ),
                              if (_waterPhoto != null || _elecPhotos.isNotEmpty) ...[
                                const SizedBox(height: BillySpace.md),
                                Wrap(spacing: BillySpace.sm, runSpacing: BillySpace.sm, children: [
                                  for (final ph in _elecPhotos) _Thumb(label: '전기', photo: ph, color: BillyColors.electricity),
                                  if (_waterPhoto != null) _Thumb(label: '수도', photo: _waterPhoto!, color: BillyColors.water),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      SectionTitle('고지서 금액', subtitle: _fields.isEmpty ? '이 요금표는 매달 넣을 고지서 금액이 없습니다' : '고지서에 적힌 그대로 넣어 주세요'),
                      if (_fields.isNotEmpty)
                        BillyCard(
                          child: LayoutBuilder(builder: (context, c) {
                            final cols = c.maxWidth >= 520 ? 2 : 1;
                            final w = (c.maxWidth - (cols - 1) * BillySpace.md) / cols;
                            return Wrap(
                              spacing: BillySpace.md,
                              runSpacing: BillySpace.md,
                              children: [for (final f in _fields) SizedBox(width: w, child: _input(f))],
                            );
                          }),
                        ),
                      for (final d in _direct) ...[
                        SectionTitle(d.item.label, subtitle: '그달 호실별로 직접 넣는 금액'),
                        BillyCard(
                          child: Column(children: [
                            for (final r in d.rows) Padding(padding: const EdgeInsets.only(bottom: BillySpace.sm), child: _input(r.$2)),
                          ]),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        StickyActionBar(
          children: [
            SizedBox(height: 46, child: AsyncButton(label: '저장', icon: Icons.save_rounded, onPressed: () async => _save())),
            SizedBox(height: 46, child: AsyncButton(label: '다음: 검토', onPressed: _saveAndNext)),
          ],
        ),
      ],
    );
  }

  Widget _input(_Field f) => TextField(
        controller: f.ctl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        style: BillyText.money(16, weight: FontWeight.w400),
        decoration: InputDecoration(labelText: f.label, suffixText: f.unit),
      );
}

class _Thumb extends StatelessWidget {
  final String label;
  final BillPhoto photo;
  final Color color;
  const _Thumb({required this.label, required this.photo, required this.color});

  @override
  Widget build(BuildContext context) {
    final img = photo.url != null
        ? Image.network(photo.url!, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72))
        : Image.memory(base64Decode(photo.base64!), width: 72, height: 72, fit: BoxFit.cover);
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        useRootNavigator: true,
        builder: (_) => Dialog(child: InteractiveViewer(child: photo.url != null ? Image.network(photo.url!) : Image.memory(base64Decode(photo.base64!)))),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BillyRadius.sm),
        child: Stack(children: [
          img,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: BillyColors.scrim,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(label, textAlign: TextAlign.center, style: BillyText.tiny.copyWith(color: color == BillyColors.water ? BillyColors.onDark : BillyColors.onDark)),
            ),
          ),
        ]),
      ),
    );
  }
}
