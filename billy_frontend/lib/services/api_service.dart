import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/bill.dart';
import '../models/building_fee.dart';
import '../models/calc_result.dart';

class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String msg;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      msg = body is Map ? (body['message']?.toString() ?? '요청 실패') : '요청 실패';
    } catch (_) {
      msg = '요청 실패';
    }
    throw Exception('$msg (${res.statusCode})');
  }

  Future<dynamic> _get(String path) async => _parse(await http.get(_uri(path), headers: _h));
  Future<dynamic> _post(String path, [Object? body]) async =>
      _parse(await http.post(_uri(path), headers: _h, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> _put(String path, [Object? body]) async =>
      _parse(await http.put(_uri(path), headers: _h, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> _delete(String path) async => _parse(await http.delete(_uri(path), headers: _h));

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async =>
      Map<String, dynamic>.from(await _post('/auth/login', {'username': username, 'password': password}));

  // ── Buildings ─────────────────────────────────────────────────────────
  Future<List<Building>> getBuildings() async =>
      ((await _get('/buildings')) as List).map((e) => Building.fromJson(e)).toList();

  Future<List<Building>> getMyBuildings() async =>
      ((await _get('/buildings/user')) as List).map((e) => Building.fromJson(e)).toList();

  Future<Building> getBuilding(int id) async => Building.fromJson(await _get('/buildings/$id'));

  Future<Building> createBuilding(Map<String, dynamic> data) async =>
      Building.fromJson(await _post('/buildings', data));

  Future<Building> updateBuilding(int id, Map<String, dynamic> data) async =>
      Building.fromJson(await _put('/buildings/$id', data));

  Future<void> deleteBuilding(int id) async => await _delete('/buildings/$id');

  // ── Floors ────────────────────────────────────────────────────────────
  Future<List<Floor>> getFloorsByBuilding(int buildingId) async =>
      ((await _get('/floors/buildings/$buildingId')) as List).map((e) => Floor.fromJson(e)).toList();

  Future<Floor> createFloor(Map<String, dynamic> data) async => Floor.fromJson(await _post('/floors', data));
  Future<Floor> updateFloor(int id, Map<String, dynamic> data) async =>
      Floor.fromJson(await _put('/floors/$id', data));
  Future<void> deleteFloor(int id) async => await _delete('/floors/$id');

  // ── Rooms ─────────────────────────────────────────────────────────────
  Future<List<Room>> getRoomsByBuilding(int buildingId) async =>
      ((await _get('/rooms/buildings/$buildingId')) as List).map((e) => Room.fromJson(e)).toList();

  Future<List<Room>> getRoomsByFloor(int floorId) async =>
      ((await _get('/rooms/floors/$floorId')) as List).map((e) => Room.fromJson(e)).toList();

  Future<Room> createRoom(Map<String, dynamic> data) async => Room.fromJson(await _post('/rooms', data));
  Future<Room> updateRoom(int id, Map<String, dynamic> data) async =>
      Room.fromJson(await _put('/rooms/$id', data));
  Future<void> deleteRoom(int id) async => await _delete('/rooms/$id');

  // ── Bills ─────────────────────────────────────────────────────────────
  Future<List<BillInfo>> getBillsByCondition({
    String month = '',
    int roomId = 0,
    int floorId = 0,
    int buildingId = 0,
  }) async {
    final q = 'month=$month&RoomId=$roomId&FloorId=$floorId&BuildingId=$buildingId';
    return ((await _get('/bills/conditions?$q')) as List).map((e) => BillInfo.fromJson(e)).toList();
  }

  /// 검침값 입력 → 사용량 계산 후 이번달 청구 생성/갱신.
  Future<void> insertMeasure(Map<String, dynamic> usage) async => await _post('/bills/measurements', usage);

  /// 관리비 계산. 응답은 roomNumber → 결과 맵.
  Future<List<CalcResult>> calculateBill(Map<String, dynamic> req) async {
    final res = await _post('/bills/calculate', req) as Map<String, dynamic>;
    return res.values.map((e) => CalcResult.fromJson(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
  }

  /// 엑셀 명세서 생성 — 바이트 반환.
  Future<List<int>> makeBillExcel(List<Map<String, dynamic>> bills) async {
    final res = await http.post(_uri('/bills/excel'), headers: _h, body: jsonEncode(bills));
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    throw Exception('엑셀 생성 실패 (${res.statusCode})');
  }

  // ── Building Fees ─────────────────────────────────────────────────────
  Future<BuildingFee> getBuildingFee(int buildingId) async {
    try {
      return BuildingFee.fromJson(await _get('/building-fees/buildings/$buildingId'));
    } catch (_) {
      return BuildingFee.empty;
    }
  }

  Future<BuildingFee> upsertBuildingFee(Map<String, dynamic> data) async =>
      BuildingFee.fromJson(await _post('/building-fees', data));

  // ── Bill Histories ────────────────────────────────────────────────────
  Future<List<dynamic>> getBillHistories(String month, int buildingId) async =>
      (await _get('/bills/histories/month/$month/building/$buildingId')) as List;

  Future<void> saveBillHistories(List<Map<String, dynamic>> histories) async =>
      await _post('/bills/histories', histories);
}
