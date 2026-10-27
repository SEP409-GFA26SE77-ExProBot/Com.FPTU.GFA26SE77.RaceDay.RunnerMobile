import 'dart:typed_data';
import 'runner_models.dart';

abstract class RunnerRepository {
  Future<RaceDetail> event(String id);
  Future<RunnerProfile> profile();
  Future<RunnerProfile> updateProfile(Json body);
  Future<List<Registration>> registrations();
  Future<Registration> registration(String id);
  Future<Registration> createRegistration(String eventId, Json body);
  Future<Registration> resubmit(String id, Json body);
  Future<Registration> cancel(String id);
  Future<Json> upload(String filename, Uint8List bytes);
  Future<String> paymentMode();
  Future<List<RunnerPayment>> payments();
  Future<RunnerPayment> checkout(String registrationId);
  Future<RunnerPayment> sync(String paymentId);
  Future<RunnerPayment> mockPay(String paymentId);
  Future<void> mockCancel(String paymentId);
}
