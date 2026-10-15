import '../../domain/entities/event_entity.dart';

class EventModel extends EventEntity {
  const EventModel({
    required super.id,
    required super.name,
    required super.location,
    required super.date,
    required super.status,
    super.tagline,
    super.bannerImage,
    super.endDate,
    super.registrationOpensAtUtc,
    super.distanceTypes,
    super.distanceKms,
  });
  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String? ?? '',
    date: json['date'] as String? ?? '',
    endDate: json['endDate'] as String?,
    status: json['status'] as String? ?? 'unknown',
    tagline: json['tagline'] as String?,
    bannerImage: json['bannerImage'] as String?,
    registrationOpensAtUtc: DateTime.tryParse(
      json['registrationOpensAtUtc']?.toString() ?? '',
    ),
    distanceTypes: (json['distanceTypes'] as List? ?? [])
        .map((e) => e.toString())
        .toList(),
    distanceKms: (json['distanceKms'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList(),
  );
}
