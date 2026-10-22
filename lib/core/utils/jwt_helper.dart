import 'dart:convert';

class JwtHelper {
  /// Safely decode JWT token payload without external native dependencies
  static Map<String, dynamic> decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Token không đúng định dạng JWT');
      }
      String payload = parts[1];
      switch (payload.length % 4) {
        case 1:
          payload += '===';
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decodedBytes = base64Url.decode(payload);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Không thể giải mã JWT: $e');
    }
  }

  /// Strictly verify if JWT payload corresponds to a Runner
  static bool isRunner(Map<String, dynamic> payload) {
    // 1. Role claim extraction
    dynamic rawRole = payload['role'] ??
        payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
        payload['roles'] ??
        payload['Role'];

    List<String> roles = [];
    if (rawRole is List) {
      roles = rawRole.map((r) => r.toString().trim().toLowerCase()).toList();
    } else if (rawRole != null) {
      roles = [rawRole.toString().trim().toLowerCase()];
    }

    // 2. RoleId GUID check (Seed: Admin: 1111..., User: 2222..., Organizer: 3333...)
    final roleId = payload['roleId']?.toString().toLowerCase();
    if (roleId != null) {
      if (roleId.startsWith('11111111')) return false; // Admin
      if (roleId.startsWith('33333333')) return false; // Organizer
      if (roleId.startsWith('22222222')) return true;  // User/Runner
    }

    // Disallow admin/organizer
    final isBlocked = roles.any((r) =>
        r.contains('admin') ||
        r.contains('organizer') ||
        r.contains('btc') ||
        r.contains('manager'));
    if (isBlocked) return false;

    // Allow Runner/User
    final isRunnerRole = roles.any((r) =>
        r == 'runner' ||
        r == 'user' ||
        r == 'vdv' ||
        r == 'athlete');

    return isRunnerRole;
  }
}
