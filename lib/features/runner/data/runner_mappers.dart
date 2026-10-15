import '../domain/runner_models.dart';
import '../domain/ticket_price_preview.dart';

RaceDetail raceDetailFromJson(Json j, {DateTime? utcNow}) {
  final org = j['organizer'] as Map? ?? {};
  final now = utcNow ?? DateTime.now().toUtc();
  DateTime? date(String key) => DateTime.tryParse(j[key]?.toString() ?? '');
  return RaceDetail(
    id: j['id'] as String,
    name: j['name'] as String,
    location: j['location'] as String? ?? '',
    date: j['date'] as String? ?? '',
    status: j['status'] as String? ?? 'unknown',
    organizerName: org['name'] as String? ?? '',
    organizerEmail: org['email'] as String? ?? '',
    organizerPhone: org['phone'] as String? ?? '',
    banner: j['bannerImage'] as String?,
    description: j['description'] as String?,
    endDate: j['endDate'] as String?,
    startTime: j['startTime'] as String?,
    opensAt: date('registrationOpensAtUtc'),
    closesAt: date('registrationClosesAtUtc'),
    packageExpiresAt: date('packageExpiresAtUtc'),
    distances: (j['distances'] as List? ?? []).map((raw) {
      final d = Map<String, dynamic>.from(raw);
      final preview = ticketPricePreview(
        j['ticketPricing'],
        d['name'] as String? ?? '',
        (d['price'] as num).toDouble(),
        now,
      );
      return RaceDistance(
        id: d['id'] as String,
        name: d['name'] as String? ?? '',
        km: (d['distanceKm'] as num).toDouble(),
        price: (d['price'] as num).toDouble(),
        estimatedPrice: preview.price,
        currency: d['currency'] as String? ?? 'VND',
        capacity: d['capacity'] as int? ?? 0,
        registered: d['registeredCount'] as int? ?? 0,
        elevation: (d['elevationGainM'] as num?)?.toDouble() ?? 0,
        startAt: d['startAt'] as String?,
        endAt: d['endAt'] as String?,
        phaseName: preview.phaseName,
        startLocation: (d['startLocation'] as Map?)?['name'] as String? ?? '',
        finishLocation: (d['finishLocation'] as Map?)?['name'] as String? ?? '',
      );
    }).toList(),
  );
}

RunnerPayment paymentFromJson(Json j) => RunnerPayment(
  id: j['id'] as String,
  status: j['status'] as String,
  registrationId: j['registrationId'] as String?,
  checkoutUrl: j['checkoutUrl'] as String?,
  amount: (j['amount'] as num).toDouble(),
  currency: j['currency'] as String? ?? 'VND',
  createdAt: DateTime.parse(j['createdAtUtc'] as String),
  qrCode: j['qrCode'] as String?,
  accountNumber: j['accountNumber'] as String?,
  accountName: j['accountName'] as String?,
  bin: j['bin'] as String?,
  transferDescription:
      j['transferDescription'] as String? ?? j['description'] as String?,
);
