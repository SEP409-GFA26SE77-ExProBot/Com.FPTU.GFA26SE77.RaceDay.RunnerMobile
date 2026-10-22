import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/domain/event_lifecycle.dart';
import '../../../../core/network/api_client.dart';
import '../models/event_model.dart';

abstract class EventRemoteDataSource {
  Future<List<EventModel>> getEvents();
  Future<EventLifecycle> getLifecycle(String id);
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final ApiClient apiClient;
  EventRemoteDataSourceImpl({ApiClient? client})
    : apiClient = client ?? ApiClient();
  @override
  Future<EventLifecycle> getLifecycle(String id) async {
    final response = await apiClient.get(ApiEndpoints.eventDetail(id));
    if (response is! Map ||
        response['id'] != id ||
        response['status'] is! String ||
        response['date'] is! String ||
        !response.containsKey('registrationClosesAtUtc') ||
        !response.containsKey('packageExpiresAtUtc')) {
      throw const FormatException('Dữ liệu trạng thái giải không hợp lệ.');
    }
    DateTime? date(String key) {
      final value = response[key];
      return value == null ? null : DateTime.parse(value.toString()).toUtc();
    }

    return EventLifecycle(
      status: response['status'] as String,
      date: response['date'] as String,
      endDate: response['endDate'] as String?,
      opensAt: date('registrationOpensAtUtc'),
      closesAt: date('registrationClosesAtUtc'),
      packageExpiresAt: date('packageExpiresAtUtc'),
    );
  }

  @override
  Future<List<EventModel>> getEvents() async {
    final response = await apiClient.get(ApiEndpoints.events);
    if (response is! List) {
      throw const FormatException('Dữ liệu danh sách giải không hợp lệ.');
    }
    return response
        .map((e) => EventModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
