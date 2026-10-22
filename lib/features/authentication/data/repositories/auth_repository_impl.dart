import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    AuthRemoteDataSource? remote,
    AuthLocalDataSource? local,
  })  : remoteDataSource = remote ?? AuthRemoteDataSourceImpl(),
        localDataSource = local ?? AuthLocalDataSourceImpl();

  @override
  Future<UserEntity> login(String username, String password) async {
    try {
      final userModel = await remoteDataSource.login(username, password);
      await localDataSource.saveUser(userModel);
      return userModel;
    } catch (e) {
      // If error occurs or role is not runner: ensure token is wiped
      await localDataSource.clearUserSession();
      rethrow;
    }
  }

  @override
  Future<UserEntity?> getSavedUser() {
    return localDataSource.getSavedUser();
  }

  @override
  Future<void> logout() {
    return localDataSource.clearUserSession();
  }

  @override
  Future<void> deleteToken() {
    return localDataSource.clearUserSession();
  }
}
