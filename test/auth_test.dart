import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_mobile/core/utils/jwt_helper.dart';

void main() {
  group('JwtHelper Role Verification Tests', () {
    String createMockJwt(Map<String, dynamic> payload) {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
      final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
      return '$header.$body.mock_signature';
    }

    test('Successfully decodes valid JWT token', () {
      final jwt = createMockJwt({
        'unique_name': 'cuong.le',
        'role': 'User',
      });

      final decoded = JwtHelper.decodePayload(jwt);
      expect(decoded['unique_name'], equals('cuong.le'));
      expect(decoded['role'], equals('User'));
    });

    test('Accepts Runner / User roles', () {
      final runnerPayload1 = {'role': 'Runner'};
      final runnerPayload2 = {'role': 'User'};
      final runnerPayload3 = {'roleId': '22222222-2222-2222-2222-222222222222'};
      final runnerPayload4 = {
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'runner'
      };

      expect(JwtHelper.isRunner(runnerPayload1), isTrue);
      expect(JwtHelper.isRunner(runnerPayload2), isTrue);
      expect(JwtHelper.isRunner(runnerPayload3), isTrue);
      expect(JwtHelper.isRunner(runnerPayload4), isTrue);
    });

    test('Strictly rejects non-runner roles (Admin, Organizer, etc.)', () {
      final adminPayload = {'role': 'Admin'};
      final organizerPayload = {'role': 'Organizer'};
      final adminRoleId = {'roleId': '11111111-1111-1111-1111-111111111111'};
      final organizerRoleId = {'roleId': '33333333-3333-3333-3333-333333333333'};
      final unknownPayload = {'role': 'Guest'};

      expect(JwtHelper.isRunner(adminPayload), isFalse);
      expect(JwtHelper.isRunner(organizerPayload), isFalse);
      expect(JwtHelper.isRunner(adminRoleId), isFalse);
      expect(JwtHelper.isRunner(organizerRoleId), isFalse);
      expect(JwtHelper.isRunner(unknownPayload), isFalse);
    });
  });
}
