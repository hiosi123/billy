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
