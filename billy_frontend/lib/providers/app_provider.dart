import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/building_fee.dart';
import '../utils/format.dart';

class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  // ── 건물 목록 ──────────────────────────────────────────────
  List<Building> buildings = [];
  bool loadingBuildings = false;

  Future<void> loadBuildings() async {
    loadingBuildings = true;
    notifyListeners();
    try {
      // 내 건물 우선, 없으면 전체(권한에 따라).
      final mine = await api.getMyBuildings();
      buildings = mine.isNotEmpty ? mine : await api.getBuildings();
    } catch (_) {
      try {
        buildings = await api.getBuildings();
      } catch (_) {
        buildings = [];
      }
    }
    loadingBuildings = false;
    notifyListeners();
  }

  Future<Building> createBuilding(Map<String, dynamic> data) async {
    final b = await api.createBuilding(data);
    await loadBuildings();
    return b;
  }

  Future<void> deleteBuilding(int id) async {
    await api.deleteBuilding(id);
    await loadBuildings();
  }

  // ── 선택된 건물 상세 ───────────────────────────────────────
  Building? selectedBuilding;
  List<Floor> floors = [];
  List<Room> rooms = [];
  BuildingFee fee = BuildingFee.empty;
  bool loadingDetail = false;

  String chargeMonth = currentChargeMonth();
  void setChargeMonth(String m) {
    chargeMonth = m;
    notifyListeners();
  }

  Future<void> selectBuilding(Building b) async {
    selectedBuilding = b;
    floors = [];
    rooms = [];
    fee = BuildingFee.empty;
    await loadDetail();
  }

  Future<void> loadDetail() async {
    if (selectedBuilding == null) return;
    final id = selectedBuilding!.buildingId;
    loadingDetail = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.getFloorsByBuilding(id),
        api.getRoomsByBuilding(id),
        api.getBuildingFee(id),
      ]);
      floors = results[0] as List<Floor>;
      rooms = results[1] as List<Room>;
      fee = results[2] as BuildingFee;
    } catch (_) {
      // 부분 실패 시 빈 상태 유지
    }
    loadingDetail = false;
    notifyListeners();
  }

  List<Room> roomsOfFloor(int floorId) => rooms.where((r) => r.floorId == floorId).toList();

  Floor? floorById(int floorId) {
    for (final f in floors) {
      if (f.floorId == floorId) return f;
    }
    return null;
  }

  // ── 층/호실/관리비 변경 ────────────────────────────────────
  Future<void> createFloor(Map<String, dynamic> data) async {
    await api.createFloor(data);
    await loadDetail();
  }

  Future<void> deleteFloor(int id) async {
    await api.deleteFloor(id);
    await loadDetail();
  }

  Future<void> createRoom(Map<String, dynamic> data) async {
    await api.createRoom(data);
    await loadDetail();
  }

  Future<void> updateRoom(int id, Map<String, dynamic> data) async {
    await api.updateRoom(id, data);
    await loadDetail();
  }

  Future<void> deleteRoom(int id) async {
    await api.deleteRoom(id);
    await loadDetail();
  }

  Future<void> saveFee(Map<String, dynamic> data) async {
    fee = await api.upsertBuildingFee(data);
    notifyListeners();
  }

  void reset() {
    buildings = [];
    selectedBuilding = null;
    floors = [];
    rooms = [];
    fee = BuildingFee.empty;
    notifyListeners();
  }
}
