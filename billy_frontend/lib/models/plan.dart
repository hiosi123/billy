import '../utils/num_parse.dart';

/// 요금표(관리비 항목 설정) — 서버 ChargePlanDef 와 같은 모양. 편집 화면에서 고친 뒤 그대로 저장한다.

/// 항목 방식 — 화면에는 쉬운 말로.
enum ChargeMethod {
  areaSplit('AREA_SPLIT', '면적 비율로 나눔', '금액 × 호실 면적 ÷ 전체 면적. 일반관리비·승강기유지비 등.'),
  equalSplit('EQUAL_SPLIT', '호실 수로 똑같이', '금액 ÷ 호실 수. 청소비 등.'),
  usageSplit('USAGE_SPLIT', '사용량 비율로 나눔', '금액 × 호실 사용량 ÷ 사용량 합계. 수도요금 등.'),
  unitPrice('UNIT_PRICE', '사용량 × 단가', '단가 = 고지서 금액 ÷ 고지서 사용량. 전기 사용분.'),
  remainder('REMAINDER', '남는 금액(공용분)을 나눔', '고지서 금액에서 호실 사용분을 뺀 나머지. 공용 전기.'),
  // '고정 금액'은 호실 화면의 호실별 금액(화재보험료 등)과 헷갈려 '같은 금액'으로 부른다
  fixedPerUnit('FIXED_PER_UNIT', '호실마다 같은 금액', '모든 호실에 같은 금액(호실별로 다르게도). TV수신료·주차비.'),
  percentOf('PERCENT_OF', '다른 항목의 %', '고른 항목들의 합 × 요율. 부가세 10% 등.'),
  unitAttr('UNIT_ATTR', '호실에 정해 둔 금액', '호실 정보의 고정 금액. 화재보험료 등.'),
  direct('DIRECT', '그달 직접 입력', '매달 호실별로 금액을 직접 넣는다. 수선비 청구 등.');

  final String code;
  final String label;
  final String help;
  const ChargeMethod(this.code, this.label, this.help);

  static ChargeMethod of(String? code) => ChargeMethod.values.firstWhere((m) => m.code == code, orElse: () => ChargeMethod.fixedPerUnit);
}

class AmountSource {
  String? input;
  double? amount;
  List<String> minusInputs;
  AmountSource({this.input, this.amount, List<String>? minusInputs}) : minusInputs = minusInputs ?? [];
  factory AmountSource.fromJson(Map<String, dynamic> j) => AmountSource(
        input: j['input']?.toString(),
        amount: toDoubleSafe(j['amount']),
        minusInputs: (j['minusInputs'] as List?)?.map((e) => e.toString()).toList(),
      );
  Map<String, dynamic> toJson() => {
        if (input != null && input!.isNotEmpty) 'input': input,
        if (amount != null) 'amount': amount,
        if (minusInputs.isNotEmpty) 'minusInputs': minusInputs,
      };
}

class PlanItem {
  String code;
  String label;
  String group;
  ChargeMethod method;
  String? utility; // electricity | water
  AmountSource? cost;
  String? usageInput;
  String? of;
  String? split; // area | usage | equal
  String? areaFormula; // mul_div | ratio
  List<String> refs;
  double? rate;
  double? amount;
  Map<String, double> perUnit;
  String? directKey;
  List<int> scopeOnly;
  List<int> scopeExclude;
  String? category;
  bool hidden;
  bool baseCostAttr;

  PlanItem({
    required this.code,
    required this.label,
    required this.group,
    required this.method,
    this.utility,
    this.cost,
    this.usageInput,
    this.of,
    this.split,
    this.areaFormula,
    List<String>? refs,
    this.rate,
    this.amount,
    Map<String, double>? perUnit,
    this.directKey,
    List<int>? scopeOnly,
    List<int>? scopeExclude,
    this.category,
    this.hidden = false,
    this.baseCostAttr = false,
  })  : refs = refs ?? [],
        perUnit = perUnit ?? {},
        scopeOnly = scopeOnly ?? [],
        scopeExclude = scopeExclude ?? [];

  factory PlanItem.fromJson(Map<String, dynamic> j) {
    final scope = j['scope'] is Map ? Map<String, dynamic>.from(j['scope']) : <String, dynamic>{};
    return PlanItem(
      code: (j['code'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      group: (j['group'] ?? '').toString(),
      method: ChargeMethod.of(j['method']?.toString()),
      utility: j['utility']?.toString(),
      cost: j['cost'] is Map ? AmountSource.fromJson(Map<String, dynamic>.from(j['cost'])) : null,
      usageInput: j['usageInput']?.toString(),
      of: j['of']?.toString(),
      split: j['split']?.toString(),
      areaFormula: j['areaFormula']?.toString(),
      refs: (j['refs'] as List?)?.map((e) => e.toString()).toList(),
      rate: toDoubleSafe(j['rate']),
      amount: toDoubleSafe(j['amount']),
      perUnit: j['perUnit'] is Map ? {for (final e in (j['perUnit'] as Map).entries) e.key.toString(): toDouble(e.value)} : null,
      directKey: j['directKey']?.toString(),
      scopeOnly: (scope['only'] as List?)?.map((e) => toInt(e)).toList(),
      scopeExclude: (scope['exclude'] as List?)?.map((e) => toInt(e)).toList(),
      category: j['category']?.toString(),
      hidden: j['hidden'] == true,
      baseCostAttr: j['attr'] == 'baseCost',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'group': group,
        'method': method.code,
        if (utility != null) 'utility': utility,
        if (cost != null && cost!.toJson().isNotEmpty) 'cost': cost!.toJson(),
        if (usageInput != null) 'usageInput': usageInput,
        if (of != null) 'of': of,
        if (split != null) 'split': split,
        if (areaFormula != null) 'areaFormula': areaFormula,
        if (refs.isNotEmpty) 'refs': refs,
        if (rate != null) 'rate': rate,
        if (amount != null) 'amount': amount,
        if (perUnit.isNotEmpty) 'perUnit': perUnit,
        if (method == ChargeMethod.unitAttr) 'attr': 'baseCost',
        if (directKey != null) 'directKey': directKey,
        if (scopeOnly.isNotEmpty || scopeExclude.isNotEmpty)
          'scope': {if (scopeOnly.isNotEmpty) 'only': scopeOnly, if (scopeExclude.isNotEmpty) 'exclude': scopeExclude},
        if (category != null && category!.isNotEmpty) 'category': category,
        if (hidden) 'hidden': true,
      };

  PlanItem copy() => PlanItem.fromJson(toJson());

  /// 금액을 매달 입력하는지(고지서 화면에 칸이 생긴다).
  bool get usesMonthlyInput => cost?.input != null;
}

class PlanGroup {
  String code;
  String label;
  PlanGroup(this.code, this.label);
  Map<String, dynamic> toJson() => {'code': code, 'label': label};
}

class PlanDef {
  String? preset;
  String roundingMode; // end | item
  String billedUnits; // with_meters | all
  List<PlanGroup> groups;
  List<PlanItem> items;
  PlanDef({this.preset, this.roundingMode = 'item', this.billedUnits = 'all', required this.groups, required this.items});

  factory PlanDef.fromJson(Map<String, dynamic> j) => PlanDef(
        preset: j['preset']?.toString(),
        roundingMode: j['roundingMode'] == 'end' ? 'end' : 'item',
        billedUnits: j['billedUnits'] == 'with_meters' ? 'with_meters' : 'all',
        groups: ((j['groups'] as List?) ?? []).map((g) => PlanGroup((g['code'] ?? '').toString(), (g['label'] ?? '').toString())).toList(),
        items: ((j['items'] as List?) ?? []).map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      );

  Map<String, dynamic> toJson() => {
        if (preset != null) 'preset': preset,
        'roundingMode': roundingMode,
        'billedUnits': billedUnits,
        'groups': groups.map((g) => g.toJson()).toList(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  PlanDef copy() => PlanDef.fromJson(toJson());

  String groupLabel(String code) => groups.firstWhere((g) => g.code == code, orElse: () => PlanGroup(code, code)).label;

  /// 새 항목 코드(겹치지 않게).
  String newCode(String base) {
    var i = 1;
    var code = base;
    while (items.any((x) => x.code == code)) {
      code = '${base}_${++i}';
    }
    return code;
  }
}

/// 법정 관리비 14항목(상가임대차법 제19조의2, 2026-05-12 시행) — 서버 catalog 와 같다.
const legalCategories = [
  '일반관리비',
  '청소비',
  '경비비',
  '소독비',
  '승강기유지비',
  '냉난방비·급탕비',
  '수선유지비',
  '위탁관리수수료',
  '전기료',
  '수도료',
  '가스사용료',
  '정화조 오물처리 수수료',
  '폐기물 처리 수수료',
  '건물 전체 보험료',
];

/// 기본 월 입력 키 이름(서버 INPUT_LABELS 와 같다).
const inputLabels = {
  'E_COST': ('전체 전기요금', '원'),
  'E_USAGE': ('전체 전기 사용량', 'kWh'),
  'W_TOTAL': ('전체 수도요금', '원'),
  'W_USAGE': ('전체 수도 사용량', 'm³'),
  'W_SUPPLY': ('상수도 요금', '원'),
  'W_SEWER': ('하수도 요금', '원'),
};
