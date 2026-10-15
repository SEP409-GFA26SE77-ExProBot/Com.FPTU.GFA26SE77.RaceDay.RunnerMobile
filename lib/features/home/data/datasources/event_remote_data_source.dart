import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/event_model.dart';

abstract class EventRemoteDataSource {
  Future<List<EventModel>> getEvents();
}

class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final ApiClient apiClient;
  EventRemoteDataSourceImpl({ApiClient? client})
    : apiClient = client ?? ApiClient();
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
