import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/v2.dart';
import '../utils/format.dart';
import '../widgets/ui.dart' show MonthStepper;

/// 앱 상태 — 건물 목록, 지금 연 건물(층·계량기·호실), 정산할 달.
/// 달은 주소(URL)가 들고 다닌다. 여기서는 '정산할 달'의 기본값만 계산한다.
class AppProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  // ── 건물 목록 ──────────────────────────────────────────────
  List<Building> buildings = [];
  // 처음엔 '불러오는 중' — 첫 화면에 '아직 건물이 없습니다'가 잠깐 비치지 않게
  bool loadingBuildings = true;
  Object? buildingsError;

  Future<void> loadBuildings() async {
    loadingBuildings = true;
    buildingsError = null;
    notifyListeners();
    try {
      buildings = await api.getBuildings(); // 서버가 볼 수 있는 건물만 준다
    } catch (e) {
      buildingsError = e;
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
    if (building?.buildingId == id) building = null;
    await loadBuildings();
  }

  // ── 지금 연 건물 ───────────────────────────────────────────
  Building? building;
  List<Floor> floors = [];
  List<Room> rooms = [];
  List<UnitV2> units = [];
  bool loadingBuilding = false;
  Object? buildingError;

  /// 정산할 달(사용월) — 마지막으로 확정한 달의 다음 달. 확정한 적이 없으면 지난달.
  String workingMonth = MonthStepper.shift(currentChargeMonth(), -1);

  int? get buildingId => building?.buildingId;

  /// 주소의 건물 번호로 연다(이미 열려 있으면 그대로).
  int _openSeq = 0; // 늦게 온 다른 건물 응답을 버린다(A 를 열다 B 로 바꾸면 A 가 B 를 덮어썼다)

  Future<void> openBuilding(int id, {bool force = false}) async {
    if (!force && building?.buildingId == id && !loadingBuilding && buildingError == null) return;
    final seq = ++_openSeq;
    loadingBuilding = true;
    buildingError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.getBuilding(id),
        api.getFloorsByBuilding(id),
        api.getRoomsByBuilding(id),
        api.getUnits(id),
        api.getOverview(id, count: 12),
      ]);
      if (seq != _openSeq) return;
      building = results[0] as Building;
      floors = results[1] as List<Floor>;
      rooms = results[2] as List<Room>;
      units = results[3] as List<UnitV2>;
      workingMonth = _workingMonthFrom((results[4] as ({int meters, List<MonthStatus> months})).months);
    } catch (e) {
      if (seq != _openSeq) return;
      buildingError = e;
    }
    loadingBuilding = false;
    notifyListeners();
  }

  /// 층·계량기·호실만 다시(호실 화면에서 고친 뒤).
  Future<void> reloadStructure() async {
    final id = buildingId;
    if (id == null) return;
    final results = await Future.wait([api.getFloorsByBuilding(id), api.getRoomsByBuilding(id), api.getUnits(id)]);
    floors = results[0] as List<Floor>;
    rooms = results[1] as List<Room>;
    units = results[2] as List<UnitV2>;
    notifyListeners();
  }

  Future<void> updateBuildingInfo(Map<String, dynamic> data) async {
    final id = buildingId;
    if (id == null) return;
    building = await api.updateBuilding(id, data);
    await loadBuildings();
  }

  static String _workingMonthFrom(List<MonthStatus> months) {
    final current = currentChargeMonth();
    final done = months.where((m) => m.issued || m.legacyTotal != null).map((m) => m.month).toList()..sort();
    if (done.isEmpty) return MonthStepper.shift(current, -1);
    final next = MonthStepper.shift(done.last, 1);
    return next.compareTo(current) > 0 ? current : next;
  }

  void setWorkingMonth(String m) {
    workingMonth = m;
    notifyListeners();
  }

  /// 계량기 표시 이름(같은 호수의 계량기 셋을 구분).
  static String meterName(Room r) => r.measureMachine.isNotEmpty ? r.measureMachine : r.roomName;

  UnitV2? unitOfRoom(int roomId) {
    for (final u in units) {
      if (u.meters.any((m) => m.roomId == roomId)) return u;
    }
    return null;
  }

  Floor? floorById(int floorId) {
    for (final f in floors) {
      if (f.floorId == floorId) return f;
    }
    return null;
  }

  /// 로그아웃·세션 만료 — 지난 계정의 건물·오류가 다음 로그인 화면에 비치지 않게 모두 비운다.
  void clear() {
    _openSeq++;
    buildings = [];
    loadingBuildings = true;
    buildingsError = null;
    building = null;
    floors = [];
    rooms = [];
    units = [];
    loadingBuilding = false;
    buildingError = null;
    notifyListeners();
  }
}
