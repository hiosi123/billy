import '../utils/num_parse.dart';

class Floor {
  final int floorId;
  final int floor;
  final double floorSpace;
  final int buildingId;

  const Floor({required this.floorId, required this.floor, required this.floorSpace, required this.buildingId});

  factory Floor.fromJson(Map<String, dynamic> j) => Floor(
        floorId: toInt(j['floorId']),
        floor: toInt(j['floor']),
        floorSpace: toDouble(j['floorSpace']),
        buildingId: toInt(j['buildingId']),
      );
}
