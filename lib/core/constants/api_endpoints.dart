import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl {
    try {
      final url = dotenv.env['API_URL'];
      if (url != null && url.isNotEmpty) {
        return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      }
    } catch (_) {}
    return 'http://localhost:5080';
  }

  // IAM Auth
  static String get login => '$baseUrl/api/v1/iam/auth/login';
  static String get register => '$baseUrl/api/v1/iam/auth/register';
  static String get verifyEmail => '$baseUrl/api/v1/iam/auth/verify-email';
  static String get resendOtp => '$baseUrl/api/v1/iam/auth/resend-otp';
  static String get forgotPassword => '$baseUrl/api/v1/iam/auth/forgot-password';
  static String get resetPassword => '$baseUrl/api/v1/iam/auth/reset-password';
  static String get changePassword => '$baseUrl/api/v1/iam/auth/change-password';

  // Events
  static String get events => '$baseUrl/api/v1/event';
  static String eventDetail(String id) => '$baseUrl/api/v1/event/$id';
}
