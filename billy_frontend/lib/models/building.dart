import '../utils/num_parse.dart';

class Building {
  final int buildingId;
  final String buildingName;
  final String buildingAddress;
  final int buildingFloors;
  final int elevator;
  final String owner;
  final int? userId;

  const Building({
    required this.buildingId,
    required this.buildingName,
    required this.buildingAddress,
    required this.buildingFloors,
    required this.elevator,
    required this.owner,
    this.userId,
  });

  bool get hasElevator => elevator > 0;

  factory Building.fromJson(Map<String, dynamic> j) => Building(
        buildingId: toInt(j['buildingId']),
        buildingName: j['buildingName'] ?? '',
        buildingAddress: j['buildingAddress'] ?? '',
        buildingFloors: toInt(j['buildingFloors']),
        elevator: toInt(j['elevator']),
        owner: j['owner'] ?? '',
        userId: toIntSafe(j['userId']),
      );
}
