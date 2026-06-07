import '../utils/num_parse.dart';

/// 확정 저장된 호실별 관리비 명세. bill_histories 테이블.
class BillHistory {
  final int billHistoryId;
  final int roomNumber;
  final String chargeMonth;
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

  const BillHistory({
    required this.billHistoryId,
    required this.roomNumber,
    required this.chargeMonth,
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

  factory BillHistory.fromJson(Map<String, dynamic> j) => BillHistory(
        billHistoryId: toInt(j['billHistoryId']),
        roomNumber: toInt(j['roomNumber']),
        chargeMonth: j['chargeMonth'] ?? '',
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

  /// 엑셀 명세서 생성 요청 바디(백엔드 ExcelBillDto, PascalCase 키).
  Map<String, dynamic> toExcelJson() => {
        'BuildingId': buildingId,
        'RoomNumber': roomNumber,
        'ChargeMonth': chargeMonth,
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
