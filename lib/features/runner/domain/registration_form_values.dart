import 'dart:convert';

/// IAM uses 0 for unknown; saved registrations may use 0/3 for Other.
String? registrationGender(Object? raw, {bool fromProfile = false}) {
  final value = raw?.toString().trim().toLowerCase();
  return switch (value) {
    '1' || 'male' || 'nam' || 'm' => 'Male',
    '2' || 'female' || 'nữ' || 'nu' || 'f' => 'Female',
    '3' || 'other' || 'khác' || 'khac' => 'Other',
    '0' when !fromProfile => 'Other',
    _ => null,
  };
}

/// Birthdays are calendar dates: do not shift the day using a UTC conversion.
String registrationBirthDate(Object? raw) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})(?:$|T|\s)',
  ).firstMatch(raw?.toString().trim() ?? '');
  if (match == null) return '';
  final value = match[1]!;
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      parsed.year != int.parse(value.substring(0, 4)) ||
      parsed.month != int.parse(value.substring(5, 7)) ||
      parsed.day != int.parse(value.substring(8, 10))) {
    return '';
  }
  return value;
}

List<String> registrationMedicalCodes(Object? raw) {
  Object? values = raw;
  if (values is String) {
    try {
      values = jsonDecode(values);
    } on FormatException {
      return [];
    }
  }
  if (values is! List) return [];
  return values
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList();
}
