import '../utils/num_parse.dart';

/// 건물 고정 관리비(면적 비례로 호실에 안분). building_fees 테이블.
class BuildingFee {
  final int buildingId;
  final double generalManagementFee;
  final double publicInspectionFee;
  final double fireManagementFee;
  final double elevatorMaintenanceFee;
  final double septicTankManagementFee;
  final double electricalManagementFee;
  final double parkingManagementFee;

  const BuildingFee({
    required this.buildingId,
    required this.generalManagementFee,
    required this.publicInspectionFee,
    required this.fireManagementFee,
    required this.elevatorMaintenanceFee,
    required this.septicTankManagementFee,
    required this.electricalManagementFee,
    required this.parkingManagementFee,
  });

  double get total =>
      generalManagementFee +
      publicInspectionFee +
      fireManagementFee +
      elevatorMaintenanceFee +
      septicTankManagementFee +
      electricalManagementFee +
      parkingManagementFee;

  factory BuildingFee.fromJson(Map<String, dynamic> j) => BuildingFee(
        buildingId: toInt(j['buildingId']),
        generalManagementFee: toDouble(j['generalManagementFee']),
        publicInspectionFee: toDouble(j['publicInspectionFee']),
        fireManagementFee: toDouble(j['fireManagementFee']),
        elevatorMaintenanceFee: toDouble(j['elevatorMaintenanceFee']),
        septicTankManagementFee: toDouble(j['septicTankManagementFee']),
        electricalManagementFee: toDouble(j['electricalManagementFee']),
        parkingManagementFee: toDouble(j['parkingManagementFee']),
      );

  static const empty = BuildingFee(
    buildingId: 0,
    generalManagementFee: 0,
    publicInspectionFee: 0,
    fireManagementFee: 0,
    elevatorMaintenanceFee: 0,
    septicTankManagementFee: 0,
    electricalManagementFee: 0,
    parkingManagementFee: 0,
  );
}
