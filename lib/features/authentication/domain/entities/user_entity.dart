import '../../../../core/utils/jwt_helper.dart';

class UserEntity {
  final String? id;
  final String username;
  final String? email;
  final String? fullName;
  final String role;
  final String token;

  const UserEntity({
    this.id,
    required this.username,
    this.email,
    this.fullName,
    required this.role,
    required this.token,
  });

  bool get isRunner => JwtHelper.isRunnerRole(role);
}
