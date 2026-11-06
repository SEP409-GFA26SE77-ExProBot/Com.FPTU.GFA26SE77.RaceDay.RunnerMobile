import '../../../../core/utils/jwt_helper.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    super.id,
    required super.username,
    super.email,
    super.fullName,
    required super.role,
    required super.token,
  });

  factory UserModel.fromToken({
    required String token,
    required Map<String, dynamic> payload,
    String? fallbackUsername,
  }) {
    final resolvedRole = JwtHelper.isRunner(payload) ? 'User' : 'Unknown';

    final id =
        payload['sub'] ??
        payload['nameid'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
        payload['userId'];

    final username =
        payload['preferred_username'] ??
        payload['unique_name'] ??
        payload['username'] ??
        fallbackUsername ??
        'Runner';

    final email =
        payload['email'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];

    final fullName =
        payload['fullName'] ??
        payload['name'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
        username;

    return UserModel(
      id: id?.toString(),
      username: username.toString(),
      email: email?.toString(),
      fullName: fullName.toString(),
      role: resolvedRole,
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'fullName': fullName,
    'role': role,
    'token': token,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    username: json['username'] ?? 'Runner',
    email: json['email'],
    fullName: json['fullName'],
    role: json['role'] ?? 'Unknown',
    token: json['token'] ?? '',
  );
}
