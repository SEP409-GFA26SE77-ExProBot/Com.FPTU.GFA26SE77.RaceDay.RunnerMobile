class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, [super.statusCode]);
}

class RoleNotAuthorizedException extends AuthException {
  RoleNotAuthorizedException(
      [super.message =
          'Tài khoản không có quyền Runner. Ứng dụng này chỉ dành cho Vận động viên tham gia giải chạy.']);
}

class NetworkException extends AppException {
  NetworkException(
      [super.message =
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.']);
}
