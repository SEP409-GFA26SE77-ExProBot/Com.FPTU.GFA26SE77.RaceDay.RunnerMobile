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
    dynamic rawRole = payload['role'] ??
        payload['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ??
        payload['roles'] ??
        payload['Role'];

    String resolvedRole = 'User';
    if (rawRole is List && rawRole.isNotEmpty) {
      resolvedRole = rawRole.first.toString();
    } else if (rawRole != null) {
      resolvedRole = rawRole.toString();
    } else {
      final roleId = payload['roleId']?.toString().toLowerCase();
      if (roleId != null && roleId.startsWith('22222222')) {
        resolvedRole = 'User';
      } else if (roleId != null && roleId.startsWith('11111111')) {
        resolvedRole = 'Admin';
      } else if (roleId != null && roleId.startsWith('33333333')) {
        resolvedRole = 'Organizer';
      }
    }

    final id = payload['sub'] ??
        payload['nameid'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'] ??
        payload['userId'];

    final username = payload['unique_name'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name'] ??
        payload['username'] ??
        fallbackUsername ??
        'Runner';

    final email = payload['email'] ??
        payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];

    final fullName = payload['fullName'] ?? payload['name'] ?? username;

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
        role: json['role'] ?? 'User',
        token: json['token'] ?? '',
      );
}
