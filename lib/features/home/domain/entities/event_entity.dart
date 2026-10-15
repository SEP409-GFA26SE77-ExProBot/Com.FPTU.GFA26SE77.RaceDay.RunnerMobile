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
  final String id, name, location, date, status;
  final String? tagline, bannerImage, startTime, description, endDate;
  final DateTime? registrationOpensAtUtc;
  final List<EventDistanceEntity> distances;
  final List<String> distanceTypes;
  final List<double> distanceKms;
  const EventEntity({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.status,
    this.tagline,
    this.bannerImage,
    this.startTime,
    this.description,
    this.endDate,
    this.registrationOpensAtUtc,
    this.distances = const [],
    this.distanceTypes = const [],
    this.distanceKms = const [],
  });
  String get statusDisplay {
    final now = DateTime.now().toUtc();
    if (status == 'registration-open') {
      if (registrationOpensAtUtc != null &&
          now.isBefore(registrationOpensAtUtc!)) {
        return 'Chưa đến giờ đăng ký';
      }
      return 'Đang mở đăng ký';
    }
    return switch (status) {
      'approved' => 'Sắp mở đăng ký',
      'closed' => 'Đã đóng đăng ký',
      'completed' => 'Đã kết thúc',
      'cancelled' => 'Đã hủy',
      'suspended' => 'Tạm ngưng',
      _ => 'Chưa mở đăng ký',
    };
  }
}
