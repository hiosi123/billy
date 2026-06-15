import 'package:shared_preferences/shared_preferences.dart';

/// 새로고침(웹) 후에도 현재 화면을 복원하기 위한 내비게이션 상태 저장.
/// 선택한 건물 / 탭 인덱스 / 청구월을 기억한다.
class NavState {
  static const _kBuilding = 'nav_building_id';
  static const _kTab = 'nav_tab_index';
  static const _kMonth = 'nav_charge_month';

  static Future<void> setBuilding(int buildingId) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kBuilding, buildingId);
  }

  static Future<void> setTab(int index) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTab, index);
  }

  static Future<void> setMonth(String month) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMonth, month);
  }

  /// 건물에서 나가거나 로그아웃 시 — 새로고침해도 홈에 머무르도록 건물 정보 제거.
  static Future<void> clearBuilding() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBuilding);
    await p.remove(_kTab);
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBuilding);
    await p.remove(_kTab);
    await p.remove(_kMonth);
  }

  static Future<({int? buildingId, int tab, String? month})> read() async {
    final p = await SharedPreferences.getInstance();
    return (
      buildingId: p.getInt(_kBuilding),
      tab: p.getInt(_kTab) ?? 0,
      month: p.getString(_kMonth),
    );
  }
}
