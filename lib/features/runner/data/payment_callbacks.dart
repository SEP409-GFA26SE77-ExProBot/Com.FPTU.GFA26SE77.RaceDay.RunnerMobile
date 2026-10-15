import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// HTTP callbacks are supplied by the client; WebAPI has no return/cancel page.
class PaymentCallbacks {
  final String returnUrl, cancelUrl;
  const PaymentCallbacks(this.returnUrl, this.cancelUrl);

  static PaymentCallbacks forApp(String apiBase) {
    String? config(String key) {
      try {
        return dotenv.env[key];
      } catch (_) {
        return null;
      }
    }

    return resolve(
      apiBase: apiBase,
      webAppUri: kIsWeb ? Uri.base : null,
      returnUrl: config('PAYMENT_RETURN_URL'),
      cancelUrl: config('PAYMENT_CANCEL_URL'),
    );
  }

  static PaymentCallbacks resolve({
    required String apiBase,
    Uri? webAppUri,
    String? returnUrl,
    String? cancelUrl,
  }) {
    // On native without a hosted callback, use the existing read-only status URL.
    // The runner returns manually; a redirect never establishes payment success.
    final fallback =
        webAppUri?.resolve('payment-return.html').toString() ??
        '$apiBase/api/v1/payment/status';
    String valid(String? value, String otherwise) {
      if (value == null || value.trim().isEmpty) return otherwise;
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw const FormatException(
          'URL quay về thanh toán phải là HTTP/HTTPS hợp lệ.',
        );
      }
      return uri.toString();
    }

    final success = valid(returnUrl, fallback);
    return PaymentCallbacks(success, valid(cancelUrl, success));
  }
}
