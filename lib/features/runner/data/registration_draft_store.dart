import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/runner_models.dart';

class RegistrationDraftStore {
  final String userId, eventId;
  const RegistrationDraftStore(this.userId, this.eventId);
  String get key => 'runner_form_${userId}_$eventId';
  Future<Json?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Json data) async {
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(data),
    );
  }

  Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
