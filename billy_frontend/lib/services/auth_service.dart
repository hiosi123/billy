import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const _tokenKey = 'billy_token';
  static const _userKey = 'billy_user';
  static String? _token;
  static User? _currentUser;

  static String? get token => _token;
  static User? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) _currentUser = User.fromJson(jsonDecode(userJson));
  }

  static Future<void> saveSession(String token, Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    _token = token;
    _currentUser = User.fromJson(userJson);
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(userJson));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    _token = null;
    _currentUser = null;
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
