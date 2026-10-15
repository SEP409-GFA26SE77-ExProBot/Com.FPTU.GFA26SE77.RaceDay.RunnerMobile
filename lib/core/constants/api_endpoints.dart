import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl {
    try {
      final url = dotenv.env['API_URL'];
      if (url != null && url.isNotEmpty) {
        var formatted = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        if (!kIsWeb && Platform.isAndroid && formatted.contains('localhost')) {
          formatted = formatted.replaceAll('localhost', '10.0.2.2');
        }
        return formatted;
      }
    } catch (_) {}

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5080';
    }
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
