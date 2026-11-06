import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../models/bill_photo.dart';
import '../../models/calc_result.dart';
import '../../utils/format.dart';
import '../../utils/image_pick.dart';
import '../../widgets/common.dart';
import '../../services/file_saver.dart';
import 'month_selector.dart';

class CalculateTab extends StatefulWidget {
  const CalculateTab({super.key});

  @override
  State<CalculateTab> createState() => _CalculateTabState();
}

class _CalculateTabState extends State<CalculateTab> {
  final _elecCost = TextEditingController();
  final _elecUsage = TextEditingController();
  final _waterCost = TextEditingController();
  final _waterUsage = TextEditingController();
  final _waterSupply = TextEditingController();
  final _waterSewer = TextEditingController();

  List<CalcResult> _results = [];
  String? _resultsMonth; // _results 를 계산한 달 — 내역 저장·엑셀은 이 달로만

  // 그 달 저장값을 불러오는 중/실패. 이때는 계산·저장을 막는다 —
  // 실패한 채로 두면 이전 달 숫자가 새 달 이름으로 저장됐다(2026-11 점검에서 재현).
  bool _loadingInput = false;
  bool _loadFailed = false;
  int _loadSeq = 0; // 늦게 도착한 이전 달 응답을 버리기 위한 순번

  // 업로드한 고지서 사진. 저장 시 S3에 올리고 URL을 보관. 전기는 보통 2장(청구서+내역서).
  BillPhoto? _waterPhoto;
  final List<BillPhoto> _elecPhotos = [];

  List<TextEditingController> get _inputs => [_elecCost, _elecUsage, _waterCost, _waterUsage, _waterSupply, _waterSewer];

  @override
  void initState() {
    super.initState();
    // 입력이 바뀌면 이전 계산 결과는 더 이상 맞지 않는다 — 지워서 옛 결과를 저장·엑셀로 내지 않게.
    for (final c in _inputs) {
      c.addListener(_invalidateResults);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedInput());
  }

  @override
  void dispose() {
    for (final c in _inputs) {
      c.dispose();
    }
    super.dispose();
  }

  void _invalidateResults() {
    if (_results.isNotEmpty && mounted) {
      setState(() {
        _results = [];
        _resultsMonth = null;
      });
    }
  }

  bool get _inputReady => !_loadingInput && !_loadFailed;

  // 콤마가 섞여 있어도 안전하게 숫자로 파싱.
  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  String _moneyOrEmpty(dynamic v) => (v is num && v != 0) ? money(v) : '';

  /// 이 건물·월에 저장된 입력값/사진을 불러와 복원. 없으면 입력칸·사진 초기화.
  /// 먼저 입력을 비우고 불러온다 — 실패하면 빈 채로 두고 계산·저장을 막는다.
  Future<void> _loadSavedInput() async {
    final p = context.read<AppProvider>();
    if (p.selectedBuilding == null) return;
    final seq = ++_loadSeq;
    final buildingId = p.selectedBuilding!.buildingId;
    final month = p.chargeMonth;
    setState(() {
      _loadingInput = true;
      _loadFailed = false;
      _results = [];
      _resultsMonth = null;
      for (final c in _inputs) {
        c.clear();
      }
      _waterPhoto = null;
      _elecPhotos.clear();
    });
    try {
      final r = await p.api.getCalcInput(buildingId, month);
      if (!mounted || seq != _loadSeq) return; // 그새 달·건물이 바뀌었으면 버린다
      setState(() {
        _loadingInput = false;
        if (r == null) return;
        _elecCost.text = _moneyOrEmpty(r['electricityTotalCost']);
        _elecUsage.text = _moneyOrEmpty(r['electricityTotalUsage']);
        _waterCost.text = _moneyOrEmpty(r['waterTotalCost']);
        _waterUsage.text = _moneyOrEmpty(r['waterTotalUsage']);
        _waterSupply.text = _moneyOrEmpty(r['waterSupplyCost']);
        _waterSewer.text = _moneyOrEmpty(r['waterSewerCost']);
        final wp = r['waterPhoto'];
        _waterPhoto = (wp is String && wp.isNotEmpty) ? BillPhoto.fromStored(wp) : null;
        _elecPhotos
          ..clear()
          ..addAll(((r['elecPhotos'] as List?) ?? [])
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .map(BillPhoto.fromStored));
      });
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loadingInput = false;
        _loadFailed = true;
      });
    }
  }

  /// 미업로드(base64) 사진은 S3에 올려 URL을 얻고, 이미 URL이면 그대로 사용.
  Future<String?> _ensureUploaded(ApiService api, BillPhoto? photo) async {
    if (photo == null) return null;
    if (photo.url != null) return photo.url;
    if (photo.base64 == null) return null;
    return api.uploadImage('bill', photo.media, base64Decode(photo.base64!));
  }

  /// 현재 입력값 + 고지서 사진을 이 건물·월에 저장. 사진은 S3 업로드 후 URL을 DB에 저장.
  Future<void> _saveInput() async {
    final p = context.read<AppProvider>();
    final api = p.api;
    if (!_inputReady) {
      // 불러오기 전·실패 상태의 빈 입력으로 그 달 저장값을 덮어쓰지 않게
      showSnack(context, '이 달 입력값을 불러온 뒤에 저장해주세요', error: true);
      return;
    }
    try {
      final waterUrl = await _ensureUploaded(api, _waterPhoto);
      final elecUrls = <String>[];
      for (final photo in _elecPhotos) {
        final u = await _ensureUploaded(api, photo);
        if (u != null) elecUrls.add(u);
      }
      // 화면 상태도 URL로 갱신(재저장 시 재업로드 방지)
      if (mounted) {
        setState(() {
          if (waterUrl != null) _waterPhoto = BillPhoto(url: waterUrl);
          _elecPhotos
            ..clear()
            ..addAll(elecUrls.map((u) => BillPhoto(url: u)));
        });
      }
      await api.saveCalcInput({
        'buildingId': p.selectedBuilding!.buildingId,
        'chargeMonth': p.chargeMonth,
        'electricityTotalCost': _n(_elecCost),
        'electricityTotalUsage': _n(_elecUsage),
        'waterTotalCost': _n(_waterCost),
        'waterTotalUsage': _n(_waterUsage),
        'waterSupplyCost': _n(_waterSupply),
        'waterSewerCost': _n(_waterSewer),
        'waterPhoto': waterUrl,
        'elecPhotos': elecUrls,
      });
      if (mounted) showSnack(context, '입력값·사진을 저장했습니다 (이 달을 다시 열면 복원됩니다)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  int _applyWater(Map r) {
    var n = 0;
    void fill(TextEditingController c, dynamic v) {
      if (v is num) {
        c.text = money(v);
        n++;
      }
    }

    fill(_waterUsage, r['waterTotalUsage']);
    fill(_waterSupply, r['waterSupplyCost']);
    fill(_waterSewer, r['waterSewerCost']);
    fill(_waterCost, r['waterTotalCost']);
    return n;
  }

  int _applyElec(Map r) {
    var n = 0;
    void fill(TextEditingController c, dynamic v) {
      if (v is num) {
        c.text = money(v);
        n++;
      }
    }

    fill(_elecCost, r['electricityTotalCost']);
    fill(_elecUsage, r['electricityTotalUsage']);
    return n;
  }

  /// 수도 고지서 1장 → AI OCR → 수도 항목 입력 + 사진 보존.
  Future<void> _readWaterBill() async {
    final picked = await pickImageBase64(context, maxWidth: 2400); // 고지서는 글자가 작아 고해상도
    if (picked == null || !mounted) return;
    final api = context.read<AppProvider>().api;
    try {
      final r = await api.readBill(image: picked.data, type: 'water', mediaType: picked.media);
      if (!mounted) return;
      final filled = _applyWater(r);
      setState(() => _waterPhoto = BillPhoto(base64: picked.data, media: picked.media));
      showSnack(context, filled > 0 ? '수도 고지서에서 $filled개 항목 입력 (사진과 비교해 확인)' : '수도 고지서에서 값을 인식하지 못했습니다',
          error: filled == 0);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 전기 고지서 여러 장(보통 청구서+내역서 2장) → 전기요금계 + 당월 사용량 종합 추출 + 사진 2장 보존.
  Future<void> _readElecBills() async {
    final images = await pickImagesBase64(maxWidth: 2400);
    if (images.isEmpty || !mounted) return;
    final p = context.read<AppProvider>();
    final api = p.api;
    try {
      final r = await api.readBillElec(
        images: images.map((e) => e.data).toList(),
        mediaType: images.first.media,
        buildingId: p.selectedBuilding?.buildingId,
        chargeMonth: p.chargeMonth,
      );
      if (!mounted) return;
      final filled = _applyElec(r);
      setState(() => _elecPhotos
        ..clear()
        ..addAll(images.map((e) => BillPhoto(base64: e.data, media: e.media))));
      showSnack(context, filled > 0 ? '전기 고지서 ${images.length}장에서 $filled개 항목 입력 (사진과 비교해 확인)' : '전기 고지서에서 값을 인식하지 못했습니다',
          error: filled == 0);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  /// 수도·전기 구분 없이 여러 장을 한 번에 업로드 → AI가 종류 자동 판별.
  /// 전기로 분류된 사진들은 함께 보고 전기요금계+당월사용량을 종합 추출한다.
  Future<void> _readBillsAuto() async {
    final images = await pickImagesBase64(maxWidth: 2400);
    if (images.isEmpty || !mounted) return;
    final p = context.read<AppProvider>();
    final api = p.api;
    final elecImgs = <({String data, String media})>[];
    var water = 0, unknown = 0;
    for (final img in images) {
      try {
        final r = await api.readBillAuto(image: img.data, mediaType: img.media);
        final type = r['type'];
        if (type == 'water') {
          _applyWater(r);
          _waterPhoto = BillPhoto(base64: img.data, media: img.media);
          water++;
        } else if (type == 'electricity') {
          elecImgs.add(img); // 전기는 모아서 합산 추출
        } else {
          unknown++;
        }
      } catch (_) {
        unknown++;
      }
    }
    var elecFilled = 0;
    if (elecImgs.isNotEmpty) {
      try {
        final er = await api.readBillElec(
          images: elecImgs.map((e) => e.data).toList(),
          mediaType: elecImgs.first.media,
          buildingId: p.selectedBuilding?.buildingId,
          chargeMonth: p.chargeMonth,
        );
        elecFilled = _applyElec(er);
        _elecPhotos
          ..clear()
          ..addAll(elecImgs.map((e) => BillPhoto(base64: e.data, media: e.media)));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    final ok = water + (elecImgs.isNotEmpty ? 1 : 0);
    showSnack(
      context,
      ok > 0
          ? '수도 $water · 전기 ${elecImgs.length}장($elecFilled항목) 인식${unknown > 0 ? ' · 분류실패 $unknown' : ''} (확인 후 계산)'
          : '고지서 종류를 인식하지 못했습니다. 개별 버튼으로 다시 시도해주세요',
      error: ok == 0,
    );
  }

  Future<void> _calculate() async {
    final p = context.read<AppProvider>();
    if (!_inputReady) {
      showSnack(context, '이 달 입력값을 불러온 뒤에 계산해주세요', error: true);
      return;
    }
    final month = p.chargeMonth;
    final seq = _loadSeq;
    final req = {
      'BuildingId': p.selectedBuilding!.buildingId,
      'Month': p.chargeMonth,
      'ElectricityTotalCost': _n(_elecCost),
      'ElectricityTotalUsage': _n(_elecUsage),
      'WaterTotalCost': _n(_waterCost),
      'WaterTotalUsage': _n(_waterUsage),
      'WaterSupplyCost': _n(_waterSupply),
      'WaterSewerCost': _n(_waterSewer),
    };
    if ((req['ElectricityTotalUsage'] as double) <= 0) {
      showSnack(context, '전체 전기 사용량을 입력해주세요', error: true);
      return;
    }
    try {
      final res = await p.api.calculateBill(req);
      if (!mounted || seq != _loadSeq || month != p.chargeMonth) return; // 계산 중에 달이 바뀌었다
      setState(() {
        _results = res;
        _resultsMonth = month;
      });
      showSnack(context, '${res.length}개 호실 계산 완료');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _downloadExcel() async {
    final p = context.read<AppProvider>();
    final month = _resultsMonth;
    if (_results.isEmpty || month == null) {
      showSnack(context, '먼저 계산을 실행해주세요', error: true);
      return;
    }
    try {
      final bytes = await p.api.makeBillExcel(
          _results.map((e) => {...e.toExcelJson(), 'ChargeMonth': month}).toList());
      final name = await saveXlsx(bytes, 'bills_$month.xlsx');
      if (mounted) showSnack(context, '엑셀 명세서 생성 완료 ($name)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _saveHistory() async {
    final p = context.read<AppProvider>();
    final month = _resultsMonth;
    if (_results.isEmpty || month == null) return;
    try {
      final payload = _results
          .map((r) => {
                'roomNumber': r.roomNumber,
                'chargeMonth': month,
                'electricityCost': r.electricityCost,
                'electricityCostCommon': r.electricityCostCommon,
                'electricityCostTax': r.electricityCostTax,
                'electricityCostFund': r.electricityCostFund,
                'electricityCostTotal': r.electricityCostTotal,
                'waterCostSupply': r.waterCostSupply,
                'waterCostSewer': r.waterCostSewer,
                'waterCostCommon': r.waterCostCommon,
                'waterCostTotal': r.waterCostTotal,
                'totalCost': r.totalCost,
                'buildingId': r.buildingId,
              })
          .toList();
      await p.api.saveBillHistories(payload);
      if (mounted) showSnack(context, '관리비 내역이 저장되었습니다 (관리비 내역 탭에서 확인)');
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final totalSum = _results.fold<double>(0, (s, r) => s + r.totalCost);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        MonthSelector(
          month: p.chargeMonth,
          onChanged: (m) {
            p.setChargeMonth(m);
            _loadSavedInput(); // 월 바꾸면 그 달 저장값 복원
          },
        ),
        if (_loadingInput) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ErrorBanner(message: '이 달 입력값을 불러오지 못했습니다. 불러온 뒤에 계산·저장할 수 있습니다.', onRetry: _loadSavedInput),
          ),
        const SizedBox(height: 14),
        SectionCard(
          title: '고지서 합계 입력',
          icon: Icons.receipt_long_outlined,
          child: Column(
            children: [
              // 고지서 사진으로 AI 자동 입력
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BillyColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 15, color: BillyColors.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('고지서를 올리면 AI가 종류를 판별해 합계를 자동 입력합니다',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BillyColors.primaryDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: AsyncButton(
                        label: '고지서 여러 장 한번에 (자동 분류)',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _readBillsAuto,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('또는 종류별로', style: TextStyle(fontSize: 11, color: BillyColors.textHint)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '수도 고지서',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.water,
                              onPressed: _readWaterBill,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: AsyncButton(
                              label: '전기 고지서 (2장)',
                              icon: Icons.photo_camera_rounded,
                              color: BillyColors.electricity,
                              onPressed: _readElecBills,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_waterPhoto != null || _elecPhotos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_waterPhoto != null) _billThumb(context, '수도 고지서', _waterPhoto!, BillyColors.water),
                          for (var i = 0; i < _elecPhotos.length; i++)
                            _billThumb(context, '전기 고지서 ${i + 1}', _elecPhotos[i], BillyColors.electricity),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _field2(
                _LabeledField(label: '전체 전기요금', controller: _elecCost, color: BillyColors.electricity, suffix: '원'),
                _LabeledField(label: '전체 전기사용량', controller: _elecUsage, color: BillyColors.electricity, suffix: 'kWh'),
              ),
              const SizedBox(height: 12),
              _field2(
                _LabeledField(label: '전체 수도요금', controller: _waterCost, color: BillyColors.water, suffix: '원'),
                _LabeledField(label: '전체 수도사용량', controller: _waterUsage, color: BillyColors.water, suffix: '㎥'),
              ),
              const SizedBox(height: 12),
              _field2(
                _LabeledField(label: '상수도 요금', controller: _waterSupply, color: BillyColors.water, suffix: '원'),
                _LabeledField(label: '하수도 요금', controller: _waterSewer, color: BillyColors.water, suffix: '원'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: AsyncButton(label: '관리비 계산하기', icon: Icons.calculate_rounded, onPressed: _calculate),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: AsyncButton(
                  label: '입력값·사진 저장',
                  icon: Icons.save_outlined,
                  color: BillyColors.textSecondary,
                  onPressed: _saveInput,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_results.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              gradient: BillyColors.headerGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: BillyColors.glow(BillyColors.headerEnd),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${chargeMonthLabel(p.chargeMonth)} 총 관리비',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(won(totalSum),
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloadExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: BillyColors.primary,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('엑셀', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: AsyncButton(
              label: '이번 계산 내역 저장',
              icon: Icons.bookmark_added_outlined,
              color: BillyColors.success,
              onPressed: _saveHistory,
            ),
          ),
          const SizedBox(height: 14),
          ..._results.map((r) => _ResultCard(result: r, building: p)),
        ],
      ],
    );
  }

  Widget _field2(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 380
            ? Column(children: [a, const SizedBox(height: 12), b])
            : Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );

  /// 업로드한 고지서 사진 썸네일(탭하면 확대). S3 URL 또는 방금 촬영한 base64 모두 표시.
  Widget _billThumb(BuildContext context, String label, BillPhoto photo, Color color) {
    Widget img({double? w, double? h}) {
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

    return SizedBox(
      width: 104,
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: InteractiveViewer(child: img()),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.image_outlined, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color))),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                img(w: 104, h: 64),
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(6))),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('탭하면 확대',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final String suffix;
  const _LabeledField({required this.label, required this.controller, required this.color, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: '0', suffixText: suffix, isDense: true),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final CalcResult result;
  final AppProvider building;
  const _ResultCard({required this.result, required this.building});

  String _roomName() {
    for (final r in building.rooms) {
      if (r.roomNumber == result.roomNumber) return r.roomName;
    }
    return '${result.roomNumber}호';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BillyColors.card(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          shape: const RoundedRectangleBorder(),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(7)),
            child: Text('${result.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          title: Text(_roomName(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          subtitle: Text(won(result.totalCost),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: BillyColors.primary)),
          children: [
            _group('전기', BillyColors.electricity, [
              KeyValueRow('사용 전기료', won(result.electricityCost)),
              KeyValueRow('공동 전기료', won(result.electricityCostCommon)),
              KeyValueRow('부가세(10%)', won(result.electricityCostTax)),
              KeyValueRow('전력기금(2.7%)', won(result.electricityCostFund)),
              KeyValueRow('전기 합계', won(result.electricityCostTotal), bold: true, valueColor: BillyColors.electricity),
            ]),
            const SizedBox(height: 8),
            _group('수도', BillyColors.water, [
              KeyValueRow('상수도', won(result.waterCostSupply)),
              KeyValueRow('하수도', won(result.waterCostSewer)),
              KeyValueRow('공동 수도', won(result.waterCostCommon)),
              KeyValueRow('수도 합계', won(result.waterCostTotal), bold: true, valueColor: BillyColors.water),
            ]),
            const Divider(height: 20),
            KeyValueRow('총 합계', won(result.totalCost), bold: true, valueColor: BillyColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _group(String title, Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: BillyColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            ]),
          ),
          ...rows,
        ],
      ),
    );
  }
}
