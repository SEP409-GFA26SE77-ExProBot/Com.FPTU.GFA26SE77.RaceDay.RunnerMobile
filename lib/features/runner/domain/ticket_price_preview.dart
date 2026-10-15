/// Client-side preview of the existing ticketPricing JSON.
/// Registration.price and Payment.amount remain the authoritative amounts.
({double price, String? phaseName}) ticketPricePreview(
  dynamic pricing,
  String distanceName,
  double listPrice,
  DateTime utcNow,
) {
  final fallback = listPrice < 0 ? 0.0 : listPrice;
  if (pricing is! Map) return (price: fallback, phaseName: null);
  var base = fallback;
  final phases = <({String key, String name, double price, Map json})>[];
  final byName = pricing['byDistanceName'];
  final row = byName is Map ? byName[distanceName] : null;
  if (row is Map) {
    base = (row['basePrice'] as num?)?.toDouble() ?? fallback;
    final values = row['phases'];
    if (values is List) {
      for (var i = 0; i < values.length; i++) {
        final p = values[i];
        if (p is! Map) continue;
        final key = p['key'] as String? ?? 'phase-$i';
        phases.add((
          key: key,
          name: p['name'] as String? ?? key,
          price: (p['price'] as num?)?.toDouble() ?? 0,
          json: p,
        ));
      }
    }
  } else if (pricing['phases'] is List) {
    for (final p in pricing['phases'] as List) {
      if (p is! Map) continue;
      final key = p['key'] as String? ?? '';
      final name = p['name'] as String? ?? key;
      final prices = p['pricesByDistanceName'];
      final price = prices is Map
          ? (prices[distanceName] as num?)?.toDouble() ?? 0.0
          : 0.0;
      if (_standard(key, name) && price > 0) base = price;
      phases.add((
        key: key,
        name: name.trim().isEmpty ? key : name,
        price: price,
        json: p,
      ));
    }
  }
  // Match backend calendar dates in Vietnam, including around UTC midnight.
  final vietnam = utcNow.toUtc().add(const Duration(hours: 7));
  final today = DateTime.utc(vietnam.year, vietnam.month, vietnam.day);
  final active = phases.where((p) {
    final from = _date(p.json['dateFrom']);
    final to = _date(p.json['dateTo']);
    return p.price > 0 &&
        (from != null || to != null) &&
        (from == null || !today.isBefore(from)) &&
        (to == null || !today.isAfter(to));
  }).toList();
  final phase =
      active.where((p) => !_standard(p.key, p.name)).firstOrNull ??
      active.where((p) => _standard(p.key, p.name)).firstOrNull;
  return (price: phase?.price ?? base, phaseName: phase?.name);
}

bool _standard(String key, String name) {
  final text = '$key $name'.toLowerCase();
  return ['regular', 'standard', 'base'].contains(key.toLowerCase()) ||
      ['regular', 'standard', 'giá gốc', 'gia goc'].any(text.contains);
}

DateTime? _date(dynamic value) {
  if (value is! String || value.length < 10) return null;
  final text = value.substring(0, 10);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != text) {
    return null;
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
