import '../../domain/entities/event_entity.dart';

class EventDistanceModel extends EventDistanceEntity {
  const EventDistanceModel({
    super.id,
    required super.name,
    required super.distanceKm,
    super.price,
    super.currency = 'VND',
    super.capacity,
  });

  factory EventDistanceModel.fromJson(Map<String, dynamic> json) {
    return EventDistanceModel(
      id: json['id']?.toString(),
      name: json['name'] ?? json['type'] ?? '${json['distanceKm'] ?? ''}km',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] ?? 'VND',
      capacity: json['capacity'] as int?,
    );
  }
}

class EventModel extends EventEntity {
  const EventModel({
    required super.id,
    required super.name,
    super.tagline,
    super.bannerImage,
    required super.location,
    required super.date,
    super.startTime,
    required super.status,
    super.description,
    super.distances = const [],
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    var rawDistances = json['distances'];
    List<EventDistanceModel> parsedDistances = [];
    if (rawDistances is List) {
      parsedDistances = rawDistances
          .map((d) => EventDistanceModel.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    return EventModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Giải chạy RaceDay',
      tagline: json['tagline'],
      bannerImage: json['bannerImage'] ?? json['banner'] ?? json['bannerUrl'],
      location: json['location'] ?? 'Việt Nam',
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString(),
      status: json['status'] ?? 'registration-open',
      description: json['description'],
      distances: parsedDistances,
    );
  }
}
