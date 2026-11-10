import '../utils/num_parse.dart';

class User {
  final int userId;
  final String username;
  final String role;

  const User({required this.userId, required this.username, required this.role});

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'admin' || role == 'manager';

  factory User.fromJson(Map<String, dynamic> j) => User(
        userId: toInt(j['userId'] ?? j['user_id']),
        username: j['username'] ?? '',
        role: j['role'] ?? 'viewer',
      );

  Map<String, dynamic> toJson() => {'userId': userId, 'username': username, 'role': role};
}

/// 계정 화면의 한 줄 — 내 계정(GET /account) · 계정 관리(GET /users) 공용.
class UserAccount {
  final int userId;
  final String username;
  final String role;
  final DateTime? createdAt;

  /// 볼 수 있는 건물(소유 + 멤버). 관리자는 이와 상관없이 모든 건물.
  final List<int> buildingIds;

  /// 소유한 건물 — 계정 관리에서 빼지 못한다.
  final List<int> ownedBuildingIds;

  const UserAccount({
    required this.userId,
    required this.username,
    required this.role,
    this.createdAt,
    this.buildingIds = const [],
    this.ownedBuildingIds = const [],
  });

  bool get isAdmin => role == 'admin';

  static List<int> _ids(dynamic v) => v is List ? v.map(toInt).toList() : const [];

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        userId: toInt(j['userId'] ?? j['user_id']),
        username: j['username'] ?? '',
        role: j['role'] ?? 'viewer',
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
        buildingIds: _ids(j['buildingIds']),
        ownedBuildingIds: _ids(j['ownedBuildingIds']),
      );
}

/// 권한 이름(화면 표기).
String roleLabel(String role) => switch (role) {
      'admin' => '관리자',
      'manager' => '매니저',
      'viewer' => '뷰어',
      _ => role,
    };
