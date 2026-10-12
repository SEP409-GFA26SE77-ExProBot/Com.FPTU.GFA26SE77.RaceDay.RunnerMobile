import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _buildHeaders({String? token, Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<dynamic> get(String url, {String? token}) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: _buildHeaders(token: token),
      ).timeout(const Duration(seconds: 8));

      return _handleResponse(response);
    } catch (e) {
      if (e is AppException) rethrow;
      final errStr = e.toString();
      final isCors = errStr.contains('XMLHttpRequest') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('ClientException');
      final msg = isCors
          ? 'Lỗi kết nối / CORS ($errStr). Vui lòng chạy Flutter Web trên port 3000 (flutter run -d chrome --web-port=3000) hoặc kiểm tra cấu hình CORS backend.'
          : 'Không thể kết nối đến máy chủ: $e';
      throw NetworkException(msg);
    }
  }

  Future<dynamic> post(String url, {dynamic body, String? token}) async {
    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: _buildHeaders(token: token),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 8));

      return _handleResponse(response);
    } catch (e) {
      if (e is AppException) rethrow;
      final errStr = e.toString();
      final isCors = errStr.contains('XMLHttpRequest') ||
          errStr.contains('Failed to fetch') ||
          errStr.contains('ClientException');
      final msg = isCors
          ? 'Lỗi kết nối / CORS ($errStr). Vui lòng chạy Flutter Web trên port 3000 (flutter run -d chrome --web-port=3000) hoặc kiểm tra cấu hình CORS backend.'
          : 'Không thể kết nối đến máy chủ: $e';
      throw NetworkException(msg);
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String errorMsg = 'Lỗi yêu cầu (${response.statusCode})';
    try {
      final errJson = jsonDecode(response.body);
      if (errJson is Map && errJson.containsKey('error')) {
        errorMsg = errJson['error'];
      } else if (errJson is Map && errJson.containsKey('message')) {
        errorMsg = errJson['message'];
      }
    } catch (_) {
      if (response.statusCode == 400) {
        errorMsg = 'Yêu cầu không hợp lệ. Vui lòng kiểm tra lại thông tin.';
      } else if (response.statusCode == 401) {
        errorMsg = 'Tài khoản hoặc mật khẩu không chính xác.';
      } else if (response.statusCode == 403) {
        errorMsg = 'Bạn không có quyền truy cập vào tài nguyên này.';
      }
    }

    throw AppException(errorMsg, response.statusCode);
  }
}
