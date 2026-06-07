import '../utils/num_parse.dart';

/// 관리비 계산 결과(호실 roomNumber 단위). /bills/calculate 응답.
class CalcResult {
  final int roomNumber;
  final double electricityCost;
  final double electricityCostCommon;
  final double electricityCostTax;
  final double electricityCostFund;
  final double electricityCostTotal;
  final double waterCostSupply;
  final double waterCostSewer;
  final double waterCostCommon;
  final double waterCostTotal;
  final double totalCost;
  final int buildingId;

  const CalcResult({
    required this.roomNumber,
    required this.electricityCost,
    required this.electricityCostCommon,
    required this.electricityCostTax,
    required this.electricityCostFund,
    required this.electricityCostTotal,
    required this.waterCostSupply,
    required this.waterCostSewer,
    required this.waterCostCommon,
    required this.waterCostTotal,
    required this.totalCost,
    required this.buildingId,
  });

  factory CalcResult.fromJson(Map<String, dynamic> j) => CalcResult(
        roomNumber: toInt(j['roomNumber']),
        electricityCost: toDouble(j['electricityCost']),
        electricityCostCommon: toDouble(j['electricityCostCommon']),
        electricityCostTax: toDouble(j['electricityCostTax']),
        electricityCostFund: toDouble(j['electricityCostFund']),
        electricityCostTotal: toDouble(j['electricityCostTotal']),
        waterCostSupply: toDouble(j['waterCostSupply']),
        waterCostSewer: toDouble(j['waterCostSewer']),
        waterCostCommon: toDouble(j['waterCostCommon']),
        waterCostTotal: toDouble(j['waterCostTotal']),
        totalCost: toDouble(j['totalCost']),
        buildingId: toInt(j['buildingId']),
      );

  /// 엑셀 생성 요청 바디(백엔드 ExcelBillDto, PascalCase 키).
  Map<String, dynamic> toExcelJson() => {
        'BuildingId': buildingId,
        'RoomNumber': roomNumber,
        'ElectricityCost': electricityCost,
        'ElectricityCostCommon': electricityCostCommon,
        'ElectricityCostTax': electricityCostTax,
        'ElectricityCostFund': electricityCostFund,
        'ElectricityCostTotal': electricityCostTotal,
        'WaterCostSupply': waterCostSupply,
        'WaterCostSewer': waterCostSewer,
        'WaterCostCommon': waterCostCommon,
        'WaterCostTotal': waterCostTotal,
        'TotalCost': totalCost,
      };
}
