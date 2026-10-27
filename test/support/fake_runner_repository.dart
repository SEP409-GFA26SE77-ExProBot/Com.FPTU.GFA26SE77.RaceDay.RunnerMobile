import 'dart:typed_data';
import 'package:runner_mobile/features/runner/domain/runner_models.dart';
import 'package:runner_mobile/features/runner/domain/runner_repository.dart';
import 'package:runner_mobile/core/errors/app_exceptions.dart';

class FakeRunnerRepository implements RunnerRepository {
  String mode = 'mock', status = 'pending_payment', paymentStatus = 'pending';
  bool failMode = false,
      failSync = false,
      timeoutAfterPay = false,
      hasPayment = true;
  int mockCalls = 0, checkoutCalls = 0, cancelCalls = 0, mockCancelCalls = 0;
  int createCalls = 0, resubmitCalls = 0;
  Future<void>? payGate;
  Json? createdBody;
  final profileData = <String, dynamic>{
    'fullName': 'Runner Test',
    'email': 'runner@example.com',
    'phone': '0901234567',
    'gender': 1,
  };
  Registration get reg => Registration({
    'id': 'r1',
    'eventId': 'e1',
    'distanceId': 'd1',
    'status': status,
    'eventName': 'RaceDay Test',
    'distanceLabel': 'Half Marathon · 21.1 km',
    'fullName': 'Runner Test',
    'email': 'runner@example.com',
    'phone': '0901234567',
    ...?createdBody,
    'price': 800000,
    'currency': 'VND',
    if (status == 'confirmed') ...{
      'bibNumber': '1001',
      'ticketCode': 'RD-test',
      'qrPayload': {
        'user_id': 'u1',
        'bib': '1001',
        'event_id': 'e1',
        'distance': 21.1,
      },
    },
    if (status == 'rejected') 'rejectionReason': 'Bổ sung hồ sơ',
  });
  RunnerPayment get pay => RunnerPayment(
    id: 'p1',
    registrationId: 'r1',
    status: paymentStatus,
    amount: 800000,
    currency: 'VND',
    createdAt: DateTime(2026),
    checkoutUrl: 'https://example.com/checkout',
    qrCode: 'TEST VIETQR PAYMENT',
    accountNumber: '123456789',
    accountName: 'RACEDAY TEST',
    bin: '970422',
    transferDescription: 'RD r1',
  );
  @override
  Future<RaceDetail> event(String id) async => RaceDetail(
    id: 'e1',
    name: 'RaceDay Test',
    location: 'Hà Nội',
    date: '2027-01-01',
    status: 'registration-open',
    organizerName: 'BTC Test',
    organizerEmail: 'btc@example.com',
    organizerPhone: '0901234567',
    distances: const [
      RaceDistance(
        id: 'd1',
        name: 'Half Marathon',
        km: 21.1,
        price: 1000000,
        estimatedPrice: 800000,
        currency: 'VND',
        capacity: 100,
        registered: 10,
        startLocation: 'Quảng trường',
        finishLocation: 'Quảng trường',
        elevation: 0,
      ),
    ],
  );
  @override
  Future<RunnerProfile> profile() async => RunnerProfile(profileData);
  @override
  Future<RunnerProfile> updateProfile(Json body) async {
    profileData.addAll(body);
    return RunnerProfile(profileData);
  }
  bool hasRegistration = true;
  @override
  Future<List<Registration>> registrations() async =>
      hasRegistration ? [reg] : [];
  @override
  Future<Registration> registration(String id) async => reg;
  @override
  Future<Registration> createRegistration(String eventId, Json body) async {
    createCalls++;
    createdBody = body;
    hasRegistration = true;
    status = 'pending_payment';
    return reg;
  }

  @override
  Future<Registration> resubmit(String id, Json body) async {
    resubmitCalls++;
    createdBody = body;
    status = 'pending_approval';
    return reg;
  }

  @override
  Future<Registration> cancel(String id) async {
    cancelCalls++;
    status = 'cancelled';
    return reg;
  }

  @override
  Future<Json> upload(String filename, Uint8List bytes) async => {
    'fileUrl': 'https://example.com/cert.pdf',
  };
  @override
  Future<String> paymentMode() async {
    if (failMode) throw NetworkException();
    return mode;
  }

  @override
  Future<List<RunnerPayment>> payments() async => hasPayment ? [pay] : [];
  @override
  Future<RunnerPayment> checkout(String registrationId) async {
    checkoutCalls++;
    hasPayment = true;
    return pay;
  }

  @override
  Future<RunnerPayment> sync(String paymentId) async {
    if (failSync) throw NetworkException();
    // Existing API does not replay Event completion for an already-paid order.
    return pay;
  }

  @override
  Future<RunnerPayment> mockPay(String paymentId) async {
    mockCalls++;
    if (payGate != null) await payGate;
    paymentStatus = 'paid';
    status = 'pending_approval';
    if (timeoutAfterPay) throw NetworkException('Timeout');
    return pay;
  }

  @override
  Future<void> mockCancel(String paymentId) async {
    mockCancelCalls++;
    paymentStatus = 'cancelled';
  }
}
