import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// HTTP callbacks are supplied by the client; WebAPI has no return/cancel page.
class PaymentCallbacks {
  static final pendingReturn = ValueNotifier<String?>(null);
  final String returnUrl, cancelUrl;
  const PaymentCallbacks(this.returnUrl, this.cancelUrl);

  static String? registrationFromLink(Uri uri) {
    if (uri.scheme != 'raceday' || uri.host != 'payment-return') return null;
    final id = uri.queryParameters['registrationId'];
    return id != null &&
            RegExp(
              r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
            ).hasMatch(id)
        ? id
        : null;
  }

  static PaymentCallbacks forRegistration(
    String apiBase,
    String registrationId,
  ) {
    final callbacks = forApp(apiBase);
    String addId(String url) {
      final uri = Uri.parse(url);
      return uri
          .replace(
            queryParameters: {
              ...uri.queryParameters,
              'registrationId': registrationId,
              if (!kIsWeb) 'native': '1',
            },
          )
          .toString();
    }

    return PaymentCallbacks(
      addId(callbacks.returnUrl),
      addId(callbacks.cancelUrl),
    );
  }

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
