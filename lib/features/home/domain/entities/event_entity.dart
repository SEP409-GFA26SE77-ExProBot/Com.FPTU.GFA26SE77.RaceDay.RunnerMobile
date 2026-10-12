class EventDistanceEntity {
  final String? id;
  final String name;
  final double distanceKm;
  final double? price;
  final String? currency;
  final int? capacity;

  const EventDistanceEntity({
    this.id,
    required this.name,
    required this.distanceKm,
    this.price,
    this.currency = 'VND',
    this.capacity,
  });
}

class EventEntity {
  final String id;
  final String name;
  final String? tagline;
  final String? bannerImage;
  final String location;
  final String date;
  final String? startTime;
  final String status;
  final String? description;
  final List<EventDistanceEntity> distances;

  const EventEntity({
    required this.id,
    required this.name,
    this.tagline,
    this.bannerImage,
    required this.location,
    required this.date,
    this.startTime,
    required this.status,
    this.description,
    this.distances = const [],
  });

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'registration-open':
        return 'Đang mở đăng ký';
      case 'approved':
        return 'Đã duyệt';
      case 'pending':
        return 'Chờ duyệt';
      case 'closed':
        return 'Đã đóng đăng ký';
      case 'completed':
        return 'Đã kết thúc';
      default:
        return status;
    }
  }
}
