String? validateRegistrationField(String key, String value, {DateTime? today}) {
  final v = value.trim();
  const required = ['fullName', 'email', 'phone'];
  if (v.isEmpty) {
    return required.contains(key) ? 'Vui lòng nhập thông tin này.' : null;
  }
  const limits = {
    'fullName': 100,
    'email': 100,
    'phone': 20,
    'idNumber': 20,
    'emergencyName': 100,
    'emergencyPhone': 20,
    'shirtType': 50,
    'shirtSize': 20,
    'shirtColor': 50,
  };
  if (limits.containsKey(key) && v.length > limits[key]!) {
    return 'Tối đa ${limits[key]} ký tự.';
  }
  if (key == 'email' && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
    return 'Email không hợp lệ.';
  }
  if (key == 'phone' || key == 'emergencyPhone') {
    final phone = v.replaceAll(RegExp(r'[\s.()\-]'), '');
    if (!RegExp(r'^(0|\+84)(3|5|7|8|9)\d{8}$').hasMatch(phone)) {
      return 'Nhập SĐT Việt Nam hợp lệ (0901234567).';
    }
  }
  if (key == 'idNumber' && !RegExp(r'^(\d{9}|\d{12})$').hasMatch(v)) {
    return 'CCCD/CMND gồm 9 hoặc 12 chữ số.';
  }
  if (key == 'bloodType' &&
      !RegExp(r'^(AB|A|B|O)[+-]?$', caseSensitive: false).hasMatch(v)) {
    return 'Nhóm máu: O, A, B, AB; có thể kèm + hoặc -.';
  }
  if (key == 'heightCm' || key == 'weightKg') {
    final n = int.tryParse(v);
    final min = key == 'heightCm' ? 100 : 25;
    if (n == null || n < min || n > 250) {
      return 'Nhập số nguyên từ $min đến 250.';
    }
  }
  if (key == 'dateOfBirth') {
    final d = DateTime.tryParse(v);
    final now = today ?? DateTime.now().toUtc();
    DateTime yearsAgo(int n) {
      final maxDay = DateTime(now.year - n, now.month + 1, 0).day;
      return DateTime(
        now.year - n,
        now.month,
        now.day > maxDay ? maxDay : now.day,
      );
    }

    if (d == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ||
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}' !=
            v ||
        d.isBefore(yearsAgo(100)) ||
        d.isAfter(yearsAgo(5))) {
      return 'Ngày sinh hợp lệ, tuổi từ 5 đến 100.';
    }
  }
  return null;
}
