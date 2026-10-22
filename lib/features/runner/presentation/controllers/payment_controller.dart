import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';

class PaymentController extends ChangeNotifier {
  final RunnerRepository repository;
  final String registrationId, userId;
  Registration? registration;
  RunnerPayment? payment;
  bool busy = false, isMock = false, verified = false, _disposed = false;
  String? error;
  PaymentController({
    required this.repository,
    required this.registrationId,
    required this.userId,
  });
  bool get canPay =>
      !busy &&
      verified &&
      registration?.status == 'pending_payment' &&
      payment?.status == 'pending';
  bool get needsReconciliation =>
      payment?.status == 'paid' &&
      ['pending_payment', 'cancelled'].contains(registration?.status);
  String get recoveryKey => 'runner_payment_${userId}_$registrationId';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _read({bool sync = true}) async {
    verified = false;
    var syncSucceeded = true;
    registration = await repository.registration(registrationId);
    final history =
        (await repository.payments())
            .where((p) => p.registrationId == registrationId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    payment = (history.where((p) => p.paid).firstOrNull ?? history.firstOrNull)
        ?.withCheckoutData(payment);
    if (sync && payment?.status == 'pending') {
      try {
        payment = (await repository.sync(
          payment!.id,
        )).withCheckoutData(payment);
      } catch (e) {
        syncSucceeded = false;
        // Read saved state after an uncertain response; do not assume sync repairs Event.
        error = e.toString();
        final updated = (await repository.payments()).where(
          (p) => p.id == payment!.id,
        );
        payment = updated.firstOrNull?.withCheckoutData(payment) ?? payment;
      }
      registration = await repository.registration(registrationId);
    }
    verified = syncSucceeded;
    if (payment != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(recoveryKey, payment!.id);
    }
  }

  Future<void> refresh({bool prepareCheckout = false}) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      try {
        isMock = await repository.paymentMode() == 'mock';
      } catch (_) {
        isMock = false;
      }
      await _read();
      if (prepareCheckout &&
          verified &&
          registration?.status == 'pending_payment' &&
          payment?.paid != true &&
          (payment == null ||
              ['cancelled', 'failed', 'expired'].contains(payment!.status) ||
              payment!.qrCode == null)) {
        payment = await repository.checkout(registrationId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(recoveryKey, payment!.id);
      }
    } catch (e) {
      error = e.toString();
      verified = false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> testPayment() async {
    if (!isMock || !canPay) return;
    busy = true;
    error = null;
    _notify();
    try {
      // The existing mock route has no server-side mode guard. Recheck before calling.
      isMock = false;
      isMock = await repository.paymentMode() == 'mock';
      if (!isMock) return;
      await _read();
      if (!verified ||
          registration?.status != 'pending_payment' ||
          payment?.status != 'pending') {
        return;
      }
      try {
        await repository.mockPay(payment!.id);
      } catch (e) {
        error = e.toString();
      }
      await _read();
    } catch (e) {
      error = e.toString();
      verified = false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> cancel() async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    var cancelled = false;
    try {
      await _read();
      if (payment?.paid == true) {
        error =
            'Thanh toán đã được ghi nhận. Không thể hủy đơn chưa thanh toán.';
      } else if (verified && registration?.status == 'pending_payment') {
        if (payment?.status == 'pending' &&
            await repository.paymentMode() == 'mock') {
          await repository.mockCancel(payment!.id);
        }
        registration = await repository.cancel(registrationId);
        cancelled = true;
      }
    } catch (e) {
      error = e.toString();
      verified = false;
    } finally {
      busy = false;
      _notify();
    }
    return cancelled;
  }

  Future<void> poll() async {
    if (busy || _disposed || payment?.status != 'pending') return;
    busy = true;
    try {
      payment = (await repository.sync(payment!.id)).withCheckoutData(payment);
      if (payment!.status != 'pending') {
        registration = await repository.registration(registrationId);
      }
      verified = true;
      error = null;
    } catch (_) {
      // Keep the QR and allow a manual retry while the next poll is pending.
      verified = false;
    } finally {
      busy = false;
      _notify();
    }
  }
}
