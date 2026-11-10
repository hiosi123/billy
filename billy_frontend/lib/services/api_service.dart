import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/building.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/bill.dart';
import '../models/v2.dart';
import '../models/plan.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');

  /// 토큰 만료/무효(401)로 더 이상 인증이 안 될 때 호출 — 전역 로그아웃+로그인 화면 이동.
  /// main.dart 에서 한 번 등록한다.
  static void Function()? onUnauthorized;
  static bool _redirectingToLogin = false;

  /// 로그인 성공 시 호출해 401 리다이렉트 가드를 푼다(재로그인 후 정상 동작).
  static void resetAuthGuard() => _redirectingToLogin = false;

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// 로그인된 상태에서 401 이면 토큰이 만료/무효 → 전역 로그아웃 트리거.
  /// (로그인 화면에서의 401(비밀번호 오류)은 토큰이 없으므로 무시된다.)
  void _checkUnauthorized(int status) {
    if (status == 401 && AuthService.isLoggedIn && !_redirectingToLogin) {
      _redirectingToLogin = true;
      onUnauthorized?.call();
    }
  }

  dynamic _parse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    _checkUnauthorized(res.statusCode);
    String msg;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final m = body is Map ? body['message'] : null;
      // 입력 검사 오류는 목록으로 온다 — '[아이디는 …]' 대괄호 그대로 보이지 않게 줄로 잇는다
      msg = m is List ? m.join('\n') : (m?.toString() ?? '');
    } catch (_) {
      msg = '';
    }
    // 화면엔 상태 번호 '(401)' 를 붙이지 않는다. 서버 기본 영어 문구('Unauthorized' 등)는 한국어로 바꾼다.
    if (res.statusCode >= 500 || !RegExp(r'[가-힣]').hasMatch(msg)) msg = _statusText(res.statusCode);
    throw Exception(msg);
  }

  static String _statusText(int status) => switch (status) {
        400 => '입력값을 확인해 주세요',
        401 => '로그인이 필요합니다. 다시 로그인해 주세요',
        403 => '이 작업을 할 권한이 없습니다',
        404 => '찾을 수 없습니다. 새로고침해 주세요',
        409 => '이미 있는 값입니다',
        413 => '파일이 너무 큽니다',
        _ when status >= 500 => '서버에 문제가 생겼습니다. 잠시 뒤 다시 해 주세요',
        _ => '요청을 처리하지 못했습니다',
      };

  /// 응답이 안 오면 무한정 기다리지 않는다(사진 인식은 길어서 따로 넉넉히).
  static const _timeout = Duration(seconds: 30);
  static const _ocrTimeout = Duration(seconds: 120);
  Duration _t(String path) => path.contains('/read-') ? _ocrTimeout : _timeout;

  Future<dynamic> _get(String path) async => _parse(await http.get(_uri(path), headers: _h).timeout(_t(path)));
  Future<dynamic> _post(String path, [Object? body]) async =>
      _parse(await http.post(_uri(path), headers: _h, body: body == null ? null : jsonEncode(body)).timeout(_t(path)));
  Future<dynamic> _put(String path, [Object? body]) async =>
      _parse(await http.put(_uri(path), headers: _h, body: body == null ? null : jsonEncode(body)).timeout(_t(path)));
  Future<dynamic> _patch(String path, [Object? body]) async =>
      _parse(await http.patch(_uri(path), headers: _h, body: body == null ? null : jsonEncode(body)).timeout(_t(path)));
  Future<dynamic> _delete(String path) async => _parse(await http.delete(_uri(path), headers: _h).timeout(_t(path)));

  // ── Auth ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = Map<String, dynamic>.from(
        await _post('/auth/login', {'username': username, 'password': password}));
    resetAuthGuard(); // 재로그인 성공 → 다음 만료에도 다시 동작하도록 가드 해제
    return res;
  }

  // ── Buildings ─────────────────────────────────────────────────────────
  Future<List<Building>> getBuildings() async =>
      ((await _get('/buildings')) as List).map((e) => Building.fromJson(e)).toList();

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

  /// 계량기 사진(base64) → AI OCR 지침값. 인식 실패 시 null.
  Future<num?> readMeter({
    required String image,
    required String type,
    double? lastValue,
    String mediaType = 'image/jpeg',
  }) async {
    final res = await _post('/bills/read-meter', {
      'image': image,
      'type': type,
      if (lastValue != null) 'lastValue': lastValue,
      'mediaType': mediaType,
    }) as Map;
    return res['value'] as num?;
  }

  /// 공공요금 고지서 사진(base64) → AI OCR 합계 항목들. type: 'water'|'electricity'.
  Future<Map<String, dynamic>> readBill({
    required String image,
    required String type,
    String mediaType = 'image/jpeg',
  }) async {
    return Map<String, dynamic>.from(
        await _post('/bills/read-bill', {'image': image, 'type': type, 'mediaType': mediaType}));
  }

  /// 고지서 사진(base64) → 수도/전기 자동 판별 + 항목 추출. 응답에 'type'(water|electricity|null) 포함.
  Future<Map<String, dynamic>> readBillAuto({
    required String image,
    String mediaType = 'image/jpeg',
  }) async {
    return Map<String, dynamic>.from(
        await _post('/bills/read-bill-auto', {'image': image, 'mediaType': mediaType}));
  }

  /// 전기 고지서 여러 장(청구서+내역서) → 전기요금계 + 당월 사용량 한번에 추출.
  /// buildingId/chargeMonth 를 주면 같은 건물의 직전 정답 예시(RAG)를 함께 보내 정확도를 높인다.
  Future<Map<String, dynamic>> readBillElec({
    required List<String> images,
    String mediaType = 'image/jpeg',
    int? buildingId,
    String? chargeMonth,
  }) async {
    return Map<String, dynamic>.from(await _post('/bills/read-bill-elec', {
      'images': images,
      'mediaType': mediaType,
      if (buildingId != null) 'buildingId': buildingId,
      if (chargeMonth != null) 'chargeMonth': chargeMonth,
    }));
  }

  // ── S3 사진 업로드 (presigned URL 방식) ─────────────────────────────────
  Future<Map<String, String>> _presignedUrl(String folder, String contentType) async {
    final data = await _post('/upload/presigned-url', {'folder': folder, 'contentType': contentType}) as Map;
    return {'uploadUrl': data['uploadUrl'] as String, 'imageUrl': data['imageUrl'] as String};
  }

  /// 이미지 바이트를 S3에 직접 PUT하고 공개 imageUrl 을 반환.
  Future<String> uploadImage(String folder, String contentType, List<int> bytes) async {
    final urls = await _presignedUrl(folder, contentType);
    // 끊기는 망에서 몇 분씩 돌지 않게 — 사진 한 장은 1분이면 충분하다
    final res = await http.put(Uri.parse(urls['uploadUrl']!), headers: {'Content-Type': contentType}, body: bytes).timeout(const Duration(seconds: 60));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('사진 업로드 실패 (${res.statusCode})');
    }
    return urls['imageUrl']!;
  }

  // ══ v2: 호실·요금표·월 마감·확정 명세서 ═══════════════════════════════════

  Future<List<UnitV2>> getUnits(int buildingId) async =>
      ((await _get('/buildings/$buildingId/units')) as List).map((e) => UnitV2.fromJson(Map<String, dynamic>.from(e))).toList();

  /// 계량기가 없는 호실만 지워진다(서버가 확인).
  Future<void> deleteUnit(int buildingId, int unitId) async => await _delete('/buildings/$buildingId/units/$unitId');

  Future<UnitV2> updateUnit(int buildingId, int unitId, Map<String, dynamic> data) async =>
      UnitV2.fromJson(Map<String, dynamic>.from(await _put('/buildings/$buildingId/units/$unitId', data)));

  /// 그달에 쓰일 요금표(+ 버전 목록·기본 프리셋).
  Future<({PlanDef plan, String source, String? effectiveFrom, List<String> versions, String defaultPreset})> getPlan(int buildingId, String month) async {
    final j = Map<String, dynamic>.from(await _get('/buildings/$buildingId/plan?month=$month'));
    return (
      plan: PlanDef.fromJson(Map<String, dynamic>.from(j['definition'])),
      source: (j['source'] ?? '').toString(),
      effectiveFrom: j['effectiveFrom']?.toString(),
      versions: ((j['versions'] as List?) ?? []).map((v) => (v['effectiveFrom'] ?? '').toString()).toList(),
      defaultPreset: (j['defaultPreset'] ?? '').toString(),
    );
  }

  Future<PlanDef> getPresetPlan(int buildingId, String presetId) async =>
      PlanDef.fromJson(Map<String, dynamic>.from(await _get('/buildings/$buildingId/plan/preset/$presetId')));

  Future<void> savePlan(int buildingId, String effectiveFrom, PlanDef plan) async =>
      await _put('/buildings/$buildingId/plan', {'effectiveFrom': effectiveFrom, 'definition': plan.toJson()});

  Future<PreviewV2> previewPlan(int buildingId, String month, PlanDef plan) async =>
      PreviewV2.fromJson(Map<String, dynamic>.from(await _post('/buildings/$buildingId/plan/preview', {'month': month, 'definition': plan.toJson()})));

  Future<({int meters, List<MonthStatus> months})> getOverview(int buildingId, {int count = 6, String? until}) async {
    final j = Map<String, dynamic>.from(await _get('/buildings/$buildingId/months?count=$count${until != null ? '&until=$until' : ''}'));
    return (
      meters: (j['meters'] as num?)?.toInt() ?? 0,
      months: ((j['months'] as List?) ?? []).map((e) => MonthStatus.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }

  /// 그달 입력값(고지서 금액 등) + 고지서 사진 URL.
  Future<({Map<String, double> values, bool saved, String? waterPhoto, List<String> elecPhotos})> getMonthInputs(int buildingId, String month) async {
    final j = Map<String, dynamic>.from(await _get('/buildings/$buildingId/months/$month/inputs'));
    final photos = Map<String, dynamic>.from(j['photos'] ?? {});
    return (
      values: {for (final e in Map<String, dynamic>.from(j['values'] ?? {}).entries) e.key: (e.value as num).toDouble()},
      saved: j['saved'] == true,
      waterPhoto: photos['water']?.toString(),
      elecPhotos: ((photos['electricity'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }

  Future<void> saveMonthInputs(int buildingId, String month, Map<String, double> values, {String? waterPhoto, List<String>? elecPhotos}) async =>
      await _put('/buildings/$buildingId/months/$month/inputs', {
        'values': values,
        if (waterPhoto != null || elecPhotos != null) 'photos': {'water': waterPhoto, 'electricity': elecPhotos ?? []},
      });

  Future<PreviewV2> previewMonth(int buildingId, String month) async =>
      PreviewV2.fromJson(Map<String, dynamic>.from(await _post('/buildings/$buildingId/months/$month/preview', {})));

  Future<List<UnitBill>> issueMonth(int buildingId, String month) async =>
      ((await _post('/buildings/$buildingId/months/$month/issue', {})) as List).map((e) => UnitBill.fromStatement(Map<String, dynamic>.from(e))).toList();

  Future<List<UnitBill>> getStatements(int buildingId, String month) async =>
      ((await _get('/buildings/$buildingId/months/$month/statements')) as List).map((e) => UnitBill.fromStatement(Map<String, dynamic>.from(e))).toList();

  Future<List<int>> statementsXlsx(int buildingId, String month) async {
    final res = await http.get(_uri('/buildings/$buildingId/months/$month/statements.xlsx'), headers: _h).timeout(_timeout);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    _checkUnauthorized(res.statusCode);
    String msg = '명세서 엑셀을 만들지 못했습니다';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['message'] != null) msg = body['message'].toString();
    } catch (_) {}
    throw Exception('$msg (${res.statusCode})');
  }

  Future<UnitBill> recordPayment(int buildingId, int statementId, {double? paidAmount, String? paidAt, String? memo}) async =>
      UnitBill.fromStatement(Map<String, dynamic>.from(await _patch('/buildings/$buildingId/statements/$statementId', {
        if (paidAmount != null) 'paidAmount': paidAmount,
        'paidAt': paidAt,
        if (memo != null) 'memo': memo,
      })));

  Future<StatementSettingsV2> getStatementSettings(int buildingId) async =>
      StatementSettingsV2.fromJson(Map<String, dynamic>.from(await _get('/buildings/$buildingId/settings')));

  Future<StatementSettingsV2> saveStatementSettings(int buildingId, StatementSettingsV2 s) async =>
      StatementSettingsV2.fromJson(Map<String, dynamic>.from(await _put('/buildings/$buildingId/settings', s.toJson())));

  // ── 내 계정 · 계정 관리(관리자) ─────────────────────────────────────────
  Future<UserAccount> getAccount() async => UserAccount.fromJson(Map<String, dynamic>.from(await _get('/account')));

  /// 새 토큰과 사용자 정보({access_token, user})를 돌려준다 — AuthService.saveSession 으로 이어 간다.
  Future<Map<String, dynamic>> changeUsername(String username, String currentPassword) async =>
      Map<String, dynamic>.from(await _put('/account/username', {'username': username, 'currentPassword': currentPassword}));

  /// 다른 기기의 로그인은 끊기고, 이 기기는 돌려준 새 토큰으로 이어 간다.
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async =>
      Map<String, dynamic>.from(await _put('/account/password', {'currentPassword': currentPassword, 'newPassword': newPassword}));

  /// 내 계정 지우기(마지막 관리자는 서버가 막는다).
  Future<void> deleteAccount(String currentPassword) async => await _post('/account/delete', {'currentPassword': currentPassword});

  Future<List<UserAccount>> getUsers() async =>
      ((await _get('/users')) as List).map((e) => UserAccount.fromJson(Map<String, dynamic>.from(e))).toList();

  Future<void> createUser({required String username, required String password, required String role, List<int>? buildingIds}) async =>
      await _post('/users', {'username': username, 'password': password, 'role': role, if (buildingIds != null) 'buildingIds': buildingIds});

  Future<void> updateUser(int userId, {String? role, String? password}) async =>
      await _put('/users/$userId', {if (role != null) 'role': role, if (password != null) 'password': password});

  Future<void> setUserBuildings(int userId, List<int> buildingIds) async => await _put('/users/$userId/buildings', {'buildingIds': buildingIds});

  Future<void> deleteUser(int userId) async => await _delete('/users/$userId');
}
