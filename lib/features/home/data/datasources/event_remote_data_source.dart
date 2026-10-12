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
    try {
      final response = await apiClient.get(ApiEndpoints.events);
      if (response != null) {
        List<dynamic> listData = [];
        if (response is List) {
          listData = response;
        } else if (response is Map && response.containsKey('data')) {
          listData = response['data'] as List;
        } else if (response is Map && response.containsKey('items')) {
          listData = response['items'] as List;
        }

        if (listData.isNotEmpty) {
          return listData
              .map((item) => EventModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Offline fallback
    }

    return _getSeedEvents();
  }

  List<EventModel> _getSeedEvents() {
    return const [
      EventModel(
        id: '11111111-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
        name: 'AQUA WARRIORS HALONG BAY VIETNAM',
        tagline: 'RACE DAY 03-04 | 04 | 27',
        bannerImage:
            'https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=1200&q=80',
        location: 'Vịnh Hạ Long, Quảng Ninh',
        date: '03-04/04/2027',
        startTime: '05:00',
        status: 'registration-open',
        description:
            'Giải bơi - chạy kết hợp quy mô quốc tế tại kỳ quan thiên nhiên thế giới Vịnh Hạ Long.',
        distances: [
          EventDistanceModel(name: '5km', distanceKm: 5.0, price: 550000),
          EventDistanceModel(name: '10km', distanceKm: 10.0, price: 850000),
          EventDistanceModel(name: '21km (Bán Marathon)', distanceKm: 21.1, price: 1150000),
        ],
      ),
      EventModel(
        id: '22222222-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
        name: 'NHA TRANG NIGHT RUN SANEST - BKH 2026',
        tagline: 'Tình yêu biển đảo',
        bannerImage:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
        location: 'Quảng Trường 2 Tháng 4, Nha Trang',
        date: '12/12/2026',
        startTime: '23:30',
        status: 'registration-open',
        description:
            'Giải chạy đêm ấn tượng dọc cung đường ven biển Trần Phú, ngắm toàn cảnh thành phố vịnh rực rỡ ánh đèn.',
        distances: [
          EventDistanceModel(name: '5km', distanceKm: 5.0, price: 450000),
          EventDistanceModel(name: '10km', distanceKm: 10.0, price: 750000),
          EventDistanceModel(name: '21km', distanceKm: 21.1, price: 1050000),
          EventDistanceModel(name: '42km (Full Marathon)', distanceKm: 42.195, price: 1350000),
        ],
      ),
      EventModel(
        id: '33333333-cccc-4ccc-8ccc-cccccccccccc',
        name: 'DA NANG INTERNATIONAL MARATHON 2026',
        tagline: 'Chinh phục cầu Rồng sông Hàn',
        bannerImage:
            'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?auto=format&fit=crop&w=1200&q=80',
        location: 'Công viên Biển Đông, Đà Nẵng',
        date: '20/08/2026',
        startTime: '04:00',
        status: 'approved',
        description:
            'Đường chạy ven biển đẹp nhất miền Trung, qua các cây cầu biểu tượng của thành phố Đà Nẵng.',
        distances: [
          EventDistanceModel(name: '5km', distanceKm: 5.0, price: 500000),
          EventDistanceModel(name: '10km', distanceKm: 10.0, price: 800000),
          EventDistanceModel(name: '21km', distanceKm: 21.1, price: 1100000),
          EventDistanceModel(name: '42km', distanceKm: 42.195, price: 1400000),
        ],
      ),
    ];
  }
}
