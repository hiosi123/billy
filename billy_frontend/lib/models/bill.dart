import '../utils/num_parse.dart';

/// 한 호실의 월별 청구(검침/사용량/요금). bills 테이블.
class Bill {
  final int billId;
  final double waterMeasure;
  final double waterUsage;
  final double waterBill;
  final double electricityMeasure;
  final double electricityUsage;
  final double electricityBill;
  final int roomId;
  final int floorId;
  final int buildingId;
  final String chargeMonth;

  const Bill({
    required this.billId,
    required this.waterMeasure,
    required this.waterUsage,
    required this.waterBill,
    required this.electricityMeasure,
    required this.electricityUsage,
    required this.electricityBill,
    required this.roomId,
    required this.floorId,
    required this.buildingId,
    required this.chargeMonth,
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        billId: toInt(j['billId']),
        waterMeasure: toDouble(j['waterMeasure']),
        waterUsage: toDouble(j['waterUsage']),
        waterBill: toDouble(j['waterBill']),
        electricityMeasure: toDouble(j['electricityMeasure']),
        electricityUsage: toDouble(j['electricityUsage']),
        electricityBill: toDouble(j['electricityBill']),
        roomId: toInt(j['roomId']),
        floorId: toInt(j['floorId']),
        buildingId: toInt(j['buildingId']),
        chargeMonth: j['chargeMonth'] ?? '',
      );
}

/// 조건 조회 결과(bills + rooms + floors 조인). /bills/conditions
class BillInfo {
  final int billId;
  final double waterUsage;
  final double waterBill;
  final double waterMeasure;
  final double electricityUsage;
  final double electricityBill;
  final double electricityMeasure;
  final String? waterMeterPhoto;
  final String? electricityMeterPhoto;
  final String chargeMonth;
  final int roomId;
  final int floorId;
  final int buildingId;
  final int roomNumber;
  final String roomName;
  final int floor;

  const BillInfo({
    required this.billId,
    required this.waterUsage,
    required this.waterBill,
    required this.waterMeasure,
    required this.electricityUsage,
    required this.electricityBill,
    required this.electricityMeasure,
    this.waterMeterPhoto,
    this.electricityMeterPhoto,
    required this.chargeMonth,
    required this.roomId,
    required this.floorId,
    required this.buildingId,
    required this.roomNumber,
    required this.roomName,
    required this.floor,
  });

  factory BillInfo.fromJson(Map<String, dynamic> j) => BillInfo(
        billId: toInt(j['billId']),
        waterUsage: toDouble(j['waterUsage']),
        waterBill: toDouble(j['waterBill']),
        waterMeasure: toDouble(j['waterMeasure']),
        electricityUsage: toDouble(j['electricityUsage']),
        electricityBill: toDouble(j['electricityBill']),
        electricityMeasure: toDouble(j['electricityMeasure']),
        waterMeterPhoto: (j['waterMeterPhoto'] as String?)?.isNotEmpty == true ? j['waterMeterPhoto'] as String : null,
        electricityMeterPhoto:
            (j['electricityMeterPhoto'] as String?)?.isNotEmpty == true ? j['electricityMeterPhoto'] as String : null,
        chargeMonth: j['chargeMonth'] ?? '',
        roomId: toInt(j['roomId']),
        floorId: toInt(j['floorId']),
        buildingId: toInt(j['buildingId']),
        roomNumber: toInt(j['roomNumber']),
        roomName: j['roomName'] ?? '',
        floor: toInt(j['floor']),
      );
}
