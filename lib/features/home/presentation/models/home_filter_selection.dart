enum HomeFilterField {
  distance,
  location,
  time,
  status,
}

class HomeFilterSelection {
  static const String defaultDistance = 'Tất cả cự ly';
  static const String defaultLocation = 'Tất cả địa điểm';
  static const String defaultTime = 'Tất cả thời gian';
  static const String defaultStatus = 'Tất cả trạng thái';

  final String distance;
  final String location;
  final String time;
  final String status;

  const HomeFilterSelection({
    this.distance = defaultDistance,
    this.location = defaultLocation,
    this.time = defaultTime,
    this.status = defaultStatus,
  });

  HomeFilterSelection copyWith({
    String? distance,
    String? location,
    String? time,
    String? status,
  }) => HomeFilterSelection(
    distance: distance ?? this.distance,
    location: location ?? this.location,
    time: time ?? this.time,
    status: status ?? this.status,
  );

  bool isFieldDefault(HomeFilterField field) {
    switch (field) {
      case HomeFilterField.distance:
        return distance == defaultDistance;
      case HomeFilterField.location:
        return location == defaultLocation;
      case HomeFilterField.time:
        return time == defaultTime;
      case HomeFilterField.status:
        return status == defaultStatus;
    }
  }

  int get activeCount {
    int count = 0;
    if (distance != defaultDistance) count++;
    if (location != defaultLocation) count++;
    if (time != defaultTime) count++;
    if (status != defaultStatus) count++;
    return count;
  }

  bool get hasActiveFilters => activeCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeFilterSelection &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          location == other.location &&
          time == other.time &&
          status == other.status;

  @override
  int get hashCode =>
      distance.hashCode ^ location.hashCode ^ time.hashCode ^ status.hashCode;

  @override
  String toString() =>
      'HomeFilterSelection(distance: $distance, location: $location, time: $time, status: $status)';
}
