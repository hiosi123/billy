import '../utils/num_parse.dart';

/// v2 모델 — 서버(billing 모듈) 응답. 숫자는 문자열로 올 수 있어 모두 toDouble/toInt 로 읽는다.

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// 계량기(기존 rooms 행).
class MeterV2 {
  final int roomId;
  final String label;
  final double measureMultiply;
  final double strictWater;
  final double strictElectricity;
  const MeterV2({required this.roomId, required this.label, required this.measureMultiply, required this.strictWater, required this.strictElectricity});
  factory MeterV2.fromJson(Map<String, dynamic> j) => MeterV2(
        roomId: toInt(j['roomId']),
        label: (j['label'] ?? '').toString(),
        measureMultiply: toDoubleSafe(j['measureMultiply']) ?? 1,
        strictWater: toDouble(j['strictWater']),
        strictElectricity: toDouble(j['strictElectricity']),
      );
}

/// 호실 = 청구 단위(면적·고정값·이름) + 계량기들.
class UnitV2 {
  final int unitId;
  final int unitNumber;
  final String name;
  final double area;
  final double baseCost;
  final int? floorId;
  final int? floor;
  final List<MeterV2> meters;
  const UnitV2({
    required this.unitId,
    required this.unitNumber,
    required this.name,
    required this.area,
    required this.baseCost,
    required this.floorId,
    required this.floor,
    required this.meters,
  });
  factory UnitV2.fromJson(Map<String, dynamic> j) => UnitV2(
        unitId: toInt(j['unitId']),
        unitNumber: toInt(j['unitNumber']),
        name: (j['name'] ?? '').toString(),
        area: toDouble(j['area']),
        baseCost: toDouble(j['baseCost']),
        floorId: toIntSafe(j['floorId']),
        floor: toIntSafe(j['floor']),
        meters: _list(j['meters']).map((e) => MeterV2.fromJson(_map(e))).toList(),
      );
  String get title => name.isEmpty ? '$unitNumber호' : '$unitNumber호 $name';
}

class MonthStatements {
  final int count;
  final double total;
  final int paidCount;
  final double paidAmount;
  final String? issuedAt;
  const MonthStatements({required this.count, required this.total, required this.paidCount, required this.paidAmount, this.issuedAt});
  factory MonthStatements.fromJson(Map<String, dynamic> j) => MonthStatements(
        count: toInt(j['count']),
        total: toDouble(j['total']),
        paidCount: toInt(j['paidCount']),
        paidAmount: toDouble(j['paidAmount']),
        issuedAt: j['issuedAt']?.toString(),
      );
}

/// 한 달 진행 현황(첫 화면).
class MonthStatus {
  final String month;
  final int readingsEntered;
  final int readingsTotal;
  final bool inputsSaved;
  final MonthStatements? statements;
  final double? legacyTotal; // 예전 앱(관리비 내역)에서 저장한 합계
  const MonthStatus({
    required this.month,
    required this.readingsEntered,
    required this.readingsTotal,
    required this.inputsSaved,
    this.statements,
    this.legacyTotal,
  });
  factory MonthStatus.fromJson(Map<String, dynamic> j) {
    final r = _map(j['readings']);
    final st = j['statements'];
    final legacy = j['legacyHistory'];
    return MonthStatus(
      month: (j['month'] ?? '').toString(),
      readingsEntered: toInt(r['entered']),
      readingsTotal: toInt(r['total']),
      inputsSaved: j['inputsSaved'] == true,
      statements: st is Map ? MonthStatements.fromJson(_map(st)) : null,
      legacyTotal: legacy is Map ? toDouble(legacy['total']) : null,
    );
  }
  bool get readingsDone => readingsTotal > 0 && readingsEntered >= readingsTotal;
  bool get issued => (statements?.count ?? 0) > 0;
  bool get allPaid => issued && statements!.paidCount >= statements!.count;
}

class EngineLineV2 {
  final String code;
  final String label;
  final String group;
  final double amount;
  final bool hidden;
  final String? category;
  const EngineLineV2({required this.code, required this.label, required this.group, required this.amount, this.hidden = false, this.category});
  factory EngineLineV2.fromJson(Map<String, dynamic> j) => EngineLineV2(
        code: (j['code'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        group: (j['group'] ?? '').toString(),
        amount: toDouble(j['amount']),
        hidden: j['hidden'] == true,
        category: j['category']?.toString(),
      );
}

class GroupTotalV2 {
  final String group;
  final String label;
  final double amount;
  const GroupTotalV2({required this.group, required this.label, required this.amount});
  factory GroupTotalV2.fromJson(Map<String, dynamic> j) =>
      GroupTotalV2(group: (j['group'] ?? '').toString(), label: (j['label'] ?? '').toString(), amount: toDouble(j['amount']));
}

/// 호실 하나의 계산 결과(미리보기) 또는 확정 명세서.
class UnitBill {
  final int unitNumber;
  final String name;
  final double area;
  final double usageElectricity;
  final double usageWater;
  final List<EngineLineV2> lines;
  final List<GroupTotalV2> groups;
  final double total;
  // 확정 명세서만
  final int? statementId;
  final double paidAmount;
  final String? paidAt;
  final String? memo;
  const UnitBill({
    required this.unitNumber,
    required this.name,
    required this.area,
    required this.usageElectricity,
    required this.usageWater,
    required this.lines,
    required this.groups,
    required this.total,
    this.statementId,
    this.paidAmount = 0,
    this.paidAt,
    this.memo,
  });

  /// 미리보기 결과(engine units[]).
  factory UnitBill.fromPreview(Map<String, dynamic> j) {
    final usage = _map(j['usage']);
    return UnitBill(
      unitNumber: toInt(j['unitNumber']),
      name: (j['name'] ?? '').toString(),
      area: toDouble(j['area']),
      usageElectricity: toDouble(usage['electricity']),
      usageWater: toDouble(usage['water']),
      lines: _list(j['lines']).map((e) => EngineLineV2.fromJson(_map(e))).toList(),
      groups: _list(j['groups']).map((e) => GroupTotalV2.fromJson(_map(e))).toList(),
      total: toDouble(_map(j['total'])['amount']),
    );
  }

  /// 확정 명세서(statements[]).
  factory UnitBill.fromStatement(Map<String, dynamic> j) {
    final usage = _map(j['usage']);
    return UnitBill(
      unitNumber: toInt(j['unitNumber']),
      name: (j['unitName'] ?? '').toString(),
      area: toDouble(j['area']),
      usageElectricity: toDouble(usage['electricity']),
      usageWater: toDouble(usage['water']),
      lines: _list(j['lines']).map((e) => EngineLineV2.fromJson(_map(e))).toList(),
      groups: _list(j['groups']).map((e) => GroupTotalV2.fromJson(_map(e))).toList(),
      total: toDouble(j['total']),
      statementId: toIntSafe(j['statementId']),
      paidAmount: toDouble(j['paidAmount']),
      paidAt: j['paidAt']?.toString(),
      memo: j['memo']?.toString(),
    );
  }

  String get title => name.isEmpty ? '$unitNumber호' : '$unitNumber호 $name';
  double get unpaid => (total - paidAmount).clamp(0, double.infinity).toDouble();
  bool get paid => statementId != null && total > 0 && paidAmount >= total;
  bool get partlyPaid => paidAmount > 0 && paidAmount < total;
}

class Issue {
  final bool error;
  final String message;
  const Issue(this.error, this.message);
}

class RequiredInput {
  final String key;
  final String label;
  final String unit;
  final double? value;
  const RequiredInput({required this.key, required this.label, required this.unit, this.value});
  factory RequiredInput.fromJson(Map<String, dynamic> j) => RequiredInput(
        key: (j['key'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        unit: (j['unit'] ?? '').toString(),
        value: toDoubleSafe(j['value']),
      );
}

/// 미리보기(쓰기 없음) 결과.
class PreviewV2 {
  final String month;
  final String planSource; // saved | default | draft
  final String? preset;
  final List<GroupTotalV2> groupsMeta;
  final List<RequiredInput> required;
  final int readingsTotal;
  final int readingsEntered;
  final List<String> readingsMissing;
  final List<UnitBill> units; // 계산 못 하면 빈 목록
  final List<Issue> issues;
  final Map<int, double> lastTotals; // 지난달 확정 합계(호수 → 금액)
  final int issuedCount;
  final String? issuedAt;
  const PreviewV2({
    required this.month,
    required this.planSource,
    required this.preset,
    required this.groupsMeta,
    required this.required,
    required this.readingsTotal,
    required this.readingsEntered,
    required this.readingsMissing,
    required this.units,
    required this.issues,
    required this.lastTotals,
    required this.issuedCount,
    this.issuedAt,
  });
  factory PreviewV2.fromJson(Map<String, dynamic> j) {
    final plan = _map(j['plan']);
    final readings = _map(j['readings']);
    final result = j['result'];
    final issued = _map(j['issued']);
    return PreviewV2(
      month: (j['month'] ?? '').toString(),
      planSource: (plan['source'] ?? '').toString(),
      preset: plan['preset']?.toString(),
      groupsMeta: _list(plan['groups']).map((g) => GroupTotalV2(group: (g['code'] ?? '').toString(), label: (g['label'] ?? '').toString(), amount: 0)).toList(),
      required: _list(_map(j['inputs'])['required']).map((e) => RequiredInput.fromJson(_map(e))).toList(),
      readingsTotal: toInt(readings['total']),
      readingsEntered: toInt(readings['entered']),
      readingsMissing: _list(readings['missing']).map((e) => e.toString()).toList(),
      units: result is Map ? _list(result['units']).map((e) => UnitBill.fromPreview(_map(e))).toList() : const [],
      issues: _list(j['issues']).map((e) => Issue(_map(e)['level'] == 'error', (_map(e)['message'] ?? '').toString())).toList(),
      lastTotals: {for (final e in _map(j['compare']).entries) toInt(e.key): toDouble(e.value)},
      issuedCount: toInt(issued['count']),
      issuedAt: issued['issuedAt']?.toString(),
    );
  }
  bool get hasErrors => issues.any((i) => i.error);
  double get total => units.fold(0.0, (s, u) => s + u.total);
}

/// 명세서 설정.
class StatementSettingsV2 {
  String managerTitle;
  String payPlace;
  String bankAccount;
  String notice;
  int meterDay;
  int? dueDay;
  double lateFeeRate;
  int truncateUnit;
  StatementSettingsV2({
    this.managerTitle = '',
    this.payPlace = '',
    this.bankAccount = '',
    this.notice = '',
    this.meterDay = 15,
    this.dueDay,
    this.lateFeeRate = 0,
    this.truncateUnit = 1,
  });
  factory StatementSettingsV2.fromJson(Map<String, dynamic> j) => StatementSettingsV2(
        managerTitle: (j['managerTitle'] ?? '').toString(),
        payPlace: (j['payPlace'] ?? '').toString(),
        bankAccount: (j['bankAccount'] ?? '').toString(),
        notice: (j['notice'] ?? '').toString(),
        meterDay: toIntSafe(j['meterDay']) ?? 15,
        dueDay: toIntSafe(j['dueDay']),
        lateFeeRate: toDouble(j['lateFeeRate']),
        truncateUnit: toIntSafe(j['truncateUnit']) ?? 1,
      );
  Map<String, dynamic> toJson() => {
        'managerTitle': managerTitle,
        'payPlace': payPlace,
        'bankAccount': bankAccount,
        'notice': notice,
        'meterDay': meterDay,
        if (dueDay != null) 'dueDay': dueDay,
        'lateFeeRate': lateFeeRate,
        'truncateUnit': truncateUnit,
      };
}
