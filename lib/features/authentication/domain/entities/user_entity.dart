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

  bool get isRunner {
    final lower = role.toLowerCase();
    return (lower.contains('runner') || lower.contains('user')) &&
        !lower.contains('admin') &&
        !lower.contains('organizer');
  }
}
