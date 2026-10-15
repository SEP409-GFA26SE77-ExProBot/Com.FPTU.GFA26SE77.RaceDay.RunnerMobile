import 'dart:convert';

typedef Json = Map<String, dynamic>;

class RaceDistance {
  final String id, name, currency, startLocation, finishLocation;
  final double km, price, estimatedPrice, elevation;
  final int capacity, registered;
  final String? startAt, endAt, phaseName;
  const RaceDistance({
    required this.id,
    required this.name,
    required this.km,
    required this.price,
    required this.estimatedPrice,
    required this.currency,
    required this.capacity,
    required this.registered,
    required this.startLocation,
    required this.finishLocation,
    required this.elevation,
    this.startAt,
    this.endAt,
    this.phaseName,
  });
  bool get hasSlot => capacity <= 0 || registered < capacity;
}

class RaceDetail {
  final String id,
      name,
      location,
      date,
      status,
      organizerName,
      organizerEmail,
      organizerPhone;
  final String? banner, description, endDate, startTime;
  final DateTime? opensAt, closesAt, packageExpiresAt;
  final List<RaceDistance> distances;
  const RaceDetail({
    required this.id,
    required this.name,
    required this.location,
    required this.date,
    required this.status,
    required this.organizerName,
    required this.organizerEmail,
    required this.organizerPhone,
    required this.distances,
    this.banner,
    this.description,
    this.endDate,
    this.startTime,
    this.opensAt,
    this.closesAt,
    this.packageExpiresAt,
  });
  bool get acceptsNow => acceptsAt(DateTime.now().toUtc());

  // Availability is derived from the existing detail contract, not a server flag.
  bool acceptsAt(DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final end = DateTime.tryParse(endDate ?? date);
    return status == 'registration-open' &&
        (end == null || !end.isBefore(today)) &&
        (opensAt == null || !now.isBefore(opensAt!)) &&
        (closesAt == null || now.isBefore(closesAt!)) &&
        (packageExpiresAt == null || now.isBefore(packageExpiresAt!));
  }

  String get registrationMessage {
    if (acceptsNow) return 'Đang mở đăng ký';
    if (status == 'completed') return 'Giải đã kết thúc';
    if (status == 'cancelled') return 'Giải đã hủy';
    final now = DateTime.now();
    final end = DateTime.tryParse(endDate ?? date);
    if (end != null && end.isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Giải đã kết thúc';
    }
    if (status == 'suspended' ||
        (packageExpiresAt != null &&
            !DateTime.now().toUtc().isBefore(packageExpiresAt!))) {
      return 'Giải tạm ngưng đăng ký';
    }
    if (closesAt != null && !DateTime.now().toUtc().isBefore(closesAt!)) {
      return 'Đã hết hạn đăng ký';
    }
    if (status == 'closed') return 'Đã đóng đăng ký';
    return 'Giải chưa mở đăng ký';
  }
}

class Registration {
  final Json data;
  Registration(Json data) : data = Map.unmodifiable(data);
  String get id => data['id'] as String;
  String get eventId => data['eventId'] as String;
  String get distanceId => data['distanceId'] as String;
  String get status => data['status'] as String;
  String get eventName => data['eventName'] as String? ?? 'Giải chạy';
  String get distanceLabel => data['distanceLabel'] as String? ?? '';
  String get fullName => data['fullName'] as String? ?? '';
  String? get bib => data['bibNumber'] as String?;
  String? get ticketCode => data['ticketCode'] as String?;
  String? get rejectionReason => data['rejectionReason'] as String?;
  double? get price => (data['price'] as num?)?.toDouble();
  String get currency => data['currency'] as String? ?? 'VND';
  DateTime? get checkedInAt =>
      DateTime.tryParse(data['checkedInAtUtc']?.toString() ?? '');
  String? get qrJson =>
      data['qrPayload'] is Map ? jsonEncode(data['qrPayload']) : null;
  bool get hasTicket =>
      status == 'confirmed' && (bib?.isNotEmpty ?? false) && qrJson != null;
  String get statusLabel => registrationStatusLabel(status);
}

String registrationStatusLabel(String status) => switch (status) {
  'pending_payment' => 'Chờ thanh toán',
  'pending_approval' => 'Chờ BTC duyệt',
  'confirmed' => 'Đã xác nhận',
  'rejected' => 'Hồ sơ bị từ chối',
  'cancelled' => 'Đã hủy',
  _ => 'Đang cập nhật',
};

class RunnerPayment {
  final String id, status, currency;
  final String? registrationId, checkoutUrl;
  final String? qrCode, accountNumber, accountName, bin, transferDescription;
  final double amount;
  final DateTime createdAt;
  const RunnerPayment({
    required this.id,
    required this.status,
    required this.currency,
    required this.amount,
    required this.createdAt,
    this.registrationId,
    this.checkoutUrl,
    this.qrCode,
    this.accountNumber,
    this.accountName,
    this.bin,
    this.transferDescription,
  });
  bool get paid => status == 'paid' || status == 'refunded';

  RunnerPayment withCheckoutData(RunnerPayment? previous) {
    if (previous == null || previous.id != id) return this;
    return RunnerPayment(
      id: id,
      status: status,
      currency: currency,
      amount: amount,
      createdAt: createdAt,
      registrationId: registrationId,
      checkoutUrl: checkoutUrl ?? previous.checkoutUrl,
      qrCode: qrCode ?? previous.qrCode,
      accountNumber: accountNumber ?? previous.accountNumber,
      accountName: accountName ?? previous.accountName,
      bin: bin ?? previous.bin,
      transferDescription: transferDescription ?? previous.transferDescription,
    );
  }
}

class RunnerProfile {
  final Json fields;
  const RunnerProfile(this.fields);
}
