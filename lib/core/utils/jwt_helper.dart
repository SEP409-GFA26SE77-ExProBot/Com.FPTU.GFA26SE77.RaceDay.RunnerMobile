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
    // Check every supplied role claim so conflicting aliases cannot grant access.
    final roles = <dynamic>[];
    for (final key in [
      'role',
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
      'roles',
      'Role',
    ]) {
      if (!payload.containsKey(key)) continue;
      final value = payload[key];
      if (value is List) {
        if (value.isEmpty) return false;
        roles.addAll(value);
      } else {
        roles.add(value);
      }
    }
    return roles.isNotEmpty &&
        roles.every((role) => role is String && isRunnerRole(role));
  }

  static bool isRunnerRole(String role) => switch (role.trim().toLowerCase()) {
    'user' || 'runner' => true,
    _ => false,
  };
}
