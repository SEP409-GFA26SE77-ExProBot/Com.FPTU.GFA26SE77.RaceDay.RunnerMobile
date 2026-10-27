import 'dart:typed_data';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../domain/runner_models.dart';
import '../domain/runner_repository.dart';
import 'runner_mappers.dart';
import 'payment_callbacks.dart';

class RunnerRepositoryImpl implements RunnerRepository {
  final String token;
  final ApiClient client;
  RunnerRepositoryImpl({required this.token, ApiClient? client})
    : client = client ?? ApiClient();
  String get base => ApiEndpoints.baseUrl;
  Future<dynamic> _get(String p) => client.get('$base/api/v1/$p', token: token);
  Future<dynamic> _post(String p, [Json? body]) =>
      client.post('$base/api/v1/$p', token: token, body: body);
  @override
  Future<RaceDetail> event(String id) async =>
      raceDetailFromJson(Map<String, dynamic>.from(await _get('event/$id')));
  @override
  Future<RunnerProfile> profile() async =>
      RunnerProfile(Map<String, dynamic>.from(await _get('iam/me')));
  @override
  Future<RunnerProfile> updateProfile(Json body) async => RunnerProfile(
    Map<String, dynamic>.from(
      await client.put('$base/api/v1/iam/me', token: token, body: body),
    ),
  );
  @override
  Future<List<Registration>> registrations() async =>
      (await _get('event/registrations/mine') as List)
          .map((e) => Registration(Map<String, dynamic>.from(e)))
          .toList();
  @override
  Future<Registration> registration(String id) async => Registration(
    Map<String, dynamic>.from(await _get('event/registrations/$id')),
  );
  @override
  Future<Registration> createRegistration(String eventId, Json body) async =>
      Registration(
        Map<String, dynamic>.from(
          await _post('event/$eventId/registrations', body),
        ),
      );
  @override
  Future<Registration> resubmit(String id, Json body) async => Registration(
    Map<String, dynamic>.from(
      await client.put(
        '$base/api/v1/event/registrations/$id/resubmit',
        token: token,
        body: body,
      ),
    ),
  );
  @override
  Future<Registration> cancel(String id) async => Registration(
    Map<String, dynamic>.from(await _post('event/registrations/$id/cancel')),
  );
  @override
  Future<Json> upload(String filename, Uint8List bytes) async =>
      Map<String, dynamic>.from(
        await client.upload(
          '$base/api/v1/event/uploads',
          token: token,
          filename: filename,
          bytes: bytes,
        ),
      );
  @override
  Future<String> paymentMode() async =>
      (await _get('payment/status'))['payOsMode'] as String;
  @override
  Future<List<RunnerPayment>> payments() async =>
      (await _get('payment/mine') as List)
          .map((e) => paymentFromJson(Map<String, dynamic>.from(e)))
          .toList();
  @override
  Future<RunnerPayment> checkout(String registrationId) async =>
      paymentFromJson(
        Map<String, dynamic>.from(
          await _post('payment/checkout', {
            'registrationId': registrationId,
            'returnUrl': PaymentCallbacks.forApp(base).returnUrl,
            'cancelUrl': PaymentCallbacks.forApp(base).cancelUrl,
          }),
        ),
      );
  @override
  Future<RunnerPayment> sync(String paymentId) async => paymentFromJson(
    Map<String, dynamic>.from(await _post('payment/$paymentId/sync')),
  );
  @override
  Future<RunnerPayment> mockPay(String paymentId) async => paymentFromJson(
    Map<String, dynamic>.from(
      await _post('payment/mock-checkout/$paymentId/pay'),
    ),
  );
  @override
  Future<void> mockCancel(String paymentId) async {
    await _post('payment/mock-checkout/$paymentId/cancel');
  }
}
