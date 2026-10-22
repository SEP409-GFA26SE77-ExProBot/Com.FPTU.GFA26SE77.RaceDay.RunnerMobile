import '../../../../core/domain/event_lifecycle.dart';

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
  final DateTime? registrationClosesAtUtc, packageExpiresAtUtc;
  final LifecycleLoadState lifecycleLoadState;
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
    this.registrationClosesAtUtc,
    this.packageExpiresAtUtc,
    this.lifecycleLoadState = LifecycleLoadState.loading,
    this.distances = const [],
    this.distanceTypes = const [],
    this.distanceKms = const [],
  });
  EventLifecycle get lifecycle => EventLifecycle(
    status: status,
    date: date,
    endDate: endDate,
    opensAt: registrationOpensAtUtc,
    closesAt: registrationClosesAtUtc,
    packageExpiresAt: packageExpiresAtUtc,
    loadState: lifecycleLoadState,
  );

  String get statusDisplay => lifecycle.stateAt(DateTime.now()).label;

  EventEntity withLifecycle(EventLifecycle value) => EventEntity(
    id: id,
    name: name,
    location: location,
    date: value.date,
    status: value.status,
    endDate: value.endDate,
    registrationOpensAtUtc: value.opensAt,
    registrationClosesAtUtc: value.closesAt,
    packageExpiresAtUtc: value.packageExpiresAt,
    lifecycleLoadState: value.loadState,
    tagline: tagline,
    bannerImage: bannerImage,
    startTime: startTime,
    description: description,
    distances: distances,
    distanceTypes: distanceTypes,
    distanceKms: distanceKms,
  );
}
