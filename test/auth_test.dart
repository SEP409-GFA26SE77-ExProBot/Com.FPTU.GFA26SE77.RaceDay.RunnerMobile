import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_mobile/core/utils/jwt_helper.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_mobile/core/errors/app_exceptions.dart';
import 'package:runner_mobile/core/network/api_client.dart';
import 'package:runner_mobile/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:runner_mobile/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:runner_mobile/features/authentication/data/models/user_model.dart';
import 'package:runner_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';

const roleClaim =
    'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

String jwt(Map<String, dynamic> claims) {
  final body = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': 'runner-1',
        'preferred_username': 'runner1',
        'username': 'runner1',
        'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name':
            'Nguyễn An',
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        ...claims,
      }),
    ),
  );
  return 'e30.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('JwtHelper Role Verification Tests', () {
    String createMockJwt(Map<String, dynamic> payload) {
      final header = base64Url.encode(
        utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
      );
      final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
      return '$header.$body.mock_signature';
    }

    test('Successfully decodes valid JWT token', () {
      final jwt = createMockJwt({'unique_name': 'cuong.le', 'role': 'User'});

      final decoded = JwtHelper.decodePayload(jwt);
      expect(decoded['unique_name'], equals('cuong.le'));
      expect(decoded['role'], equals('User'));
    });

    test('Accepts Runner / User roles', () {
      final runnerPayload1 = {'role': 'Runner'};
      final runnerPayload2 = {'role': 'User'};
      final runnerPayload3 = {'role': 'User', roleClaim: 'User'};
      final runnerPayload4 = {
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role':
            'runner',
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
      final organizerRoleId = {
        'roleId': '33333333-3333-3333-3333-333333333333',
      };
      final unknownPayload = {'role': 'Guest'};

      expect(JwtHelper.isRunner(adminPayload), isFalse);
      expect(JwtHelper.isRunner(organizerPayload), isFalse);
      expect(JwtHelper.isRunner(adminRoleId), isFalse);
      expect(JwtHelper.isRunner(organizerRoleId), isFalse);
      expect(JwtHelper.isRunner(unknownPayload), isFalse);
    });
  });

  test('Rejects other IAM roles, missing roles and conflicting claims', () {
    for (final payload in <Map<String, dynamic>>[
      {},
      {'roleId': '22222222-2222-2222-2222-222222222222'},
      for (final role in [
        'Admin',
        'Organizer',
        'Race-staff',
        'Photographer',
        'Manager',
        'Coordinator',
        'Volunteer',
        'Guest',
        'superuser',
        'runner-manager',
      ])
        {'role': role},
      {'role': 'Manager', 'roleId': '22222222-2222-2222-2222-222222222222'},
      {
        'role': ['User', 'Race-staff'],
      },
      {'role': 'User', roleClaim: 'Manager'},
      {
        'role': 'User',
        'roles': ['Photographer'],
      },
      {'role': []},
      {'role': null},
    ]) {
      expect(JwtHelper.isRunner(payload), isFalse, reason: '$payload');
      expect(
        UserModel.fromToken(token: jwt(payload), payload: payload).isRunner,
        isFalse,
        reason: '$payload',
      );
    }
    expect(
      const UserEntity(username: 'x', role: 'superuser', token: '').isRunner,
      isFalse,
    );
  });

  test('Accepts normalized User and Runner claims consistently', () {
    for (final payload in <Map<String, dynamic>>[
      {'role': 'User', roleClaim: 'User'},
      {'role': ' Runner '},
      {roleClaim: 'user'},
      {
        'roles': ['User', 'Runner'],
      },
      {'Role': 'USER'},
    ]) {
      expect(JwtHelper.isRunner(payload), isTrue, reason: '$payload');
      expect(
        UserModel.fromToken(token: jwt(payload), payload: payload).isRunner,
        isTrue,
      );
    }
  });

  test(
    'Restored session uses the checked JWT instead of a stale profile',
    () async {
      final token = jwt({'role': 'User', roleClaim: 'User'});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('raceday_access_token', token);
      await prefs.setString(
        'raceday_user_profile',
        jsonEncode({
          'id': 'old-user',
          'username': 'old',
          'role': 'Manager',
          'token': 'old-token',
        }),
      );
      final user = await AuthLocalDataSourceImpl().getSavedUser();
      expect(user!.id, 'runner-1');
      expect(user.username, 'runner1');
      expect(user.fullName, 'Nguyễn An');
      expect(user.isRunner, isTrue);
      expect(user.token, token);
    },
  );

  test('Expired and non-runner JWTs clear saved sessions', () async {
    final session = AuthLocalDataSourceImpl();
    for (final claims in [
      {'role': 'User', 'exp': 1},
      {'role': 'Race-staff'},
      {'role': 'Manager'},
      {'role': 'User', roleClaim: 'Photographer'},
    ]) {
      await session.saveUser(
        UserModel(username: 'runner', role: 'User', token: jwt(claims)),
      );
      expect(await session.getSavedUser(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('raceday_access_token'), isNull);
      expect(prefs.getString('raceday_user_profile'), isNull);
    }
  });

  test(
    'User login works and a staff login clears the previous session',
    () async {
      var role = 'User';
      final session = AuthLocalDataSourceImpl();
      final repo = AuthRepositoryImpl(
        local: session,
        remote: AuthRemoteDataSourceImpl(
          client: ApiClient(
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'accessToken': jwt({'role': role, roleClaim: role}),
                }),
                200,
              ),
            ),
          ),
        ),
      );
      final user = await repo.login('runner1', 'password123');
      expect(user.username, 'runner1');
      expect(user.fullName, 'Nguyễn An');
      expect((await session.getSavedUser())!.isRunner, isTrue);
      role = 'Race-staff';
      await expectLater(
        repo.login('staff', 'password123'),
        throwsA(isA<RoleNotAuthorizedException>()),
      );
      expect(await session.getSavedUser(), isNull);
    },
  );
}
