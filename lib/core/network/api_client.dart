import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../errors/app_exceptions.dart';

class ApiClient {
  final http.Client _client;
  static void Function()? onSessionExpired;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
  Future<dynamic> get(String url, {String? token}) =>
      _request('GET', url, token: token);
  Future<dynamic> post(String url, {dynamic body, String? token}) =>
      _request('POST', url, token: token, body: body);
  Future<dynamic> put(String url, {dynamic body, String? token}) =>
      _request('PUT', url, token: token, body: body);

  Future<dynamic> _request(
    String method,
    String url, {
    String? token,
    dynamic body,
  }) async {
    final request = http.Request(method, Uri.parse(url));
    request.headers.addAll(_headers(token));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return _send(request, token, const Duration(seconds: 25));
  }

  Future<dynamic> upload(
    String url, {
    required String token,
    required String filename,
    required Uint8List bytes,
  }) {
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll(_headers(token))
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    return _send(request, token, const Duration(seconds: 90));
  }

  Future<dynamic> _send(
    http.BaseRequest request,
    String? token,
    Duration timeout,
  ) async {
    try {
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      return _handleResponse(response, authenticated: token != null);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw NetworkException(
        'Máy chủ chưa phản hồi. Vui lòng kiểm tra trạng thái trước khi thử lại.',
      );
    } catch (_) {
      throw NetworkException(
        'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }

  dynamic _handleResponse(
    http.Response response, {
    required bool authenticated,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (response.statusCode == 401 && authenticated) {
      onSessionExpired?.call();
      throw AuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        401,
      );
    }
    String message = switch (response.statusCode) {
      401 => 'Tên đăng nhập hoặc mật khẩu không chính xác.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
      _ => 'Không thể thực hiện yêu cầu (${response.statusCode}).',
    };
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map) {
        message = (data['error'] ?? data['message'] ?? message).toString();
      }
    } catch (_) {}
    throw AppException(message, response.statusCode);
  }
}
