import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/jwt_helper.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getSavedUser();
  Future<void> clearUserSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _tokenKey = 'raceday_access_token';
  static const String _userKey = 'raceday_user_profile';

  @override
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, user.token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  @override
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final payload = JwtHelper.decodePayload(token);
      final expiry = payload['exp'];
      if (expiry is! num ||
          DateTime.now().toUtc().millisecondsSinceEpoch >= expiry * 1000) {
        await clearUserSession();
        return null;
      }
      if (!JwtHelper.isRunner(payload)) {
        await clearUserSession();
        return null;
      }

      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        return UserModel.fromJson(jsonDecode(userJson));
      }

      return UserModel.fromToken(token: token, payload: payload);
    } catch (_) {
      await clearUserSession();
      return null;
    }
  }

  @override
  Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
