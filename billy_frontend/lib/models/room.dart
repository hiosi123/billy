import '../utils/num_parse.dart';

class Room {
  final int roomId;
  final int roomNumber;
  final double roomBaseCost;
  final String measureMachine;
  final String roomName;
  final double roomSpace;
  final double strictWater;
  final double strictElectricity;
  final int measureNo;
  final double measureMultiply;
  final int floorId;
  final int buildingId;
  final int? floor; // floors 조인 표시용

  const Room({
    required this.roomId,
    required this.roomNumber,
    required this.roomBaseCost,
    required this.measureMachine,
    required this.roomName,
    required this.roomSpace,
    required this.strictWater,
    required this.strictElectricity,
    required this.measureNo,
    required this.measureMultiply,
    required this.floorId,
    required this.buildingId,
    this.floor,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        roomId: toInt(j['roomId']),
        roomNumber: toInt(j['roomNumber']),
        roomBaseCost: toDouble(j['roomBaseCost']),
        measureMachine: j['measureMachine'] ?? '',
        roomName: j['roomName'] ?? '',
        roomSpace: toDouble(j['roomSpace']),
        strictWater: toDouble(j['strictWater']),
        strictElectricity: toDouble(j['strictElectricity']),
        measureNo: toInt(j['measureNo']),
        measureMultiply: toDouble(j['measureMultiply']),
        floorId: toInt(j['floorId']),
        buildingId: toInt(j['buildingId']),
        floor: toIntSafe(j['floor']),
      );
}
