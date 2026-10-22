enum LifecycleLoadState { loading, ready, failed }

enum EventRegistrationState {
  loading('Đang kiểm tra trạng thái'),
  unknown('Chưa xác định trạng thái'),
  ended('Đã kết thúc'),
  cancelled('Đã hủy'),
  suspended('Giải tạm ngưng đăng ký'),
  expired('Đã hết hạn đăng ký'),
  closed('Đã đóng đăng ký'),
  scheduled('Chưa đến giờ đăng ký'),
  upcoming('Sắp mở đăng ký'),
  open('Đang mở đăng ký'),
  unavailable('Chưa mở đăng ký');

  final String label;
  const EventRegistrationState(this.label);
}

/// Shared availability rules for public cards, filters and registration detail.
class EventLifecycle {
  final String status, date;
  final String? endDate;
  final DateTime? opensAt, closesAt, packageExpiresAt;
  final LifecycleLoadState loadState;

  const EventLifecycle({
    required this.status,
    required this.date,
    this.endDate,
    this.opensAt,
    this.closesAt,
    this.packageExpiresAt,
    this.loadState = LifecycleLoadState.ready,
  });

  EventRegistrationState stateAt(DateTime now) {
    if (status == 'completed') return EventRegistrationState.ended;
    if (status == 'cancelled') return EventRegistrationState.cancelled;
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final end = DateTime.tryParse(endDate ?? date);
    if (end != null && end.isBefore(today)) {
      return EventRegistrationState.ended;
    }
    // A missing list field is not evidence that the deadline is unrestricted.
    if (loadState == LifecycleLoadState.loading) {
      return EventRegistrationState.loading;
    }
    if (loadState == LifecycleLoadState.failed) {
      return EventRegistrationState.unknown;
    }
    final utcNow = now.toUtc();
    if (status == 'suspended' ||
        (packageExpiresAt != null && !utcNow.isBefore(packageExpiresAt!))) {
      return EventRegistrationState.suspended;
    }
    if (closesAt != null && !utcNow.isBefore(closesAt!)) {
      return EventRegistrationState.expired;
    }
    if (status == 'closed') return EventRegistrationState.closed;
    if (status == 'registration-open') {
      if (opensAt != null && utcNow.isBefore(opensAt!)) {
        return EventRegistrationState.scheduled;
      }
      return EventRegistrationState.open;
    }
    if (status == 'approved') return EventRegistrationState.upcoming;
    return EventRegistrationState.unavailable;
  }
}

/// Schedule only clock boundaries, without polling the API.
DateTime nextLifecycleChange(Iterable<EventLifecycle> events, DateTime now) {
  final local = now.toLocal();
  var next = DateTime(local.year, local.month, local.day + 1);
  for (final event in events) {
    for (final deadline in [
      event.opensAt,
      event.closesAt,
      event.packageExpiresAt,
    ]) {
      if (deadline != null &&
          deadline.isAfter(now) &&
          deadline.isBefore(next)) {
        next = deadline;
      }
    }
  }
  return next;
}
