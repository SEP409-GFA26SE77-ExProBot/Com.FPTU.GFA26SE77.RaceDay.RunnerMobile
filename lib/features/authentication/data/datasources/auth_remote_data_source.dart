import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/jwt_helper.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String username, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;
  AuthRemoteDataSourceImpl({ApiClient? client})
    : apiClient = client ?? ApiClient();

  @override
  Future<UserModel> login(String username, String password) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      body: {'username': username.trim(), 'password': password},
    );
    if (response is! Map) {
      throw AuthException('Phản hồi đăng nhập không hợp lệ.');
    }
    final token = response['accessToken'] ?? response['token'];
    if (token is! String || token.isEmpty) {
      throw AuthException('Phản hồi không chứa accessToken.');
    }
    final payload = JwtHelper.decodePayload(token);
    if (!JwtHelper.isRunner(payload)) throw RoleNotAuthorizedException();
    return UserModel.fromToken(
      token: token,
      payload: payload,
      fallbackUsername: username,
    );
  }
}
