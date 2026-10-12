import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login(String username, String password);
  Future<UserEntity?> getSavedUser();
  Future<void> logout();
  Future<void> deleteToken();
}
