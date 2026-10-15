import 'registration_validation.dart';
import 'runner_models.dart';

const medicalOptions = {
  'cardiovascular': 'Bệnh lý tim mạch',
  'respiratory': 'Bệnh lý hô hấp',
  'cns': 'Bệnh lý hệ thần kinh trung ương',
  'injury': 'Chấn thương',
  'thermoregulation': 'Rối loạn thân nhiệt',
  'electrolyte': 'Rối loạn nước điện giải',
  'consciousness': 'Rối loạn tri giác',
  'seizure': 'Co giật',
  'pregnancy': 'Phụ nữ đang mang thai',
  'none': 'Không mắc bệnh lý đặc biệt',
};
const emergencyRelations = [
  'Ba/Mẹ',
  'Chồng/Vợ',
  'Anh/Chị/Em',
  'Người thân',
  'Bạn bè',
];
const bloodOptions = [
  'O+',
  'O-',
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O',
  'A',
  'B',
  'AB',
];
const shirtSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

List<String> toggleMedical(List<String> values, String code) {
  if (code == 'none') return values.contains(code) ? [] : ['none'];
  final result = values.where((v) => v != 'none').toList();
  if (!result.remove(code)) result.add(code);
  return result;
}

String normalizeRunnerPhone(String value) => value
    .trim()
    .replaceAll(RegExp(r'[\s.\-()]'), '')
    .replaceFirst(RegExp(r'^\+84'), '0');

String? validateHealthFile(String name, int bytes) {
  if (!RegExp(r'\.(pdf|jpe?g|png)$', caseSensitive: false).hasMatch(name)) {
    return 'Chỉ chấp nhận PDF, JPG, PNG.';
  }
  if (bytes <= 0) return 'File trống. Vui lòng chọn lại.';
  if (bytes > 5 * 1024 * 1024) return 'File tối đa 5MB.';
  return null;
}

/// Mirrors UserWeb register/page.tsx step validation; API still validates on submit.
Map<String, String> validateRunnerStep(
  int step,
  Json data, {
  DateTime? today,
  bool hasCertificate = false,
}) {
  final errors = <String, String>{};
  String value(String key) => data[key]?.toString().trim() ?? '';
  void field(String key, {bool required = false}) {
    if (required && value(key).isEmpty) {
      errors[key] = 'Vui lòng nhập thông tin này.';
    } else {
      final error = validateRegistrationField(key, value(key), today: today);
      if (error != null) errors[key] = error;
    }
  }

  if (step == 0 && value('distanceId').isEmpty) {
    errors['distanceId'] = 'Vui lòng chọn cự ly.';
  }
  if (step == 1) {
    for (final key in [
      'fullName',
      'email',
      'phone',
      'dateOfBirth',
      'idNumber',
    ]) {
      field(key, required: true);
    }
    if (!['Male', 'Female', 'Other'].contains(value('gender'))) {
      errors['gender'] = 'Vui lòng chọn giới tính.';
    }
    if (value('bibName').length > 40) {
      errors['bibName'] = 'Tên trên BIB tối đa 40 ký tự.';
    }
  }
  if (step == 2) {
    for (final key in ['bloodType', 'emergencyName', 'emergencyPhone']) {
      field(key, required: true);
    }
    if (value('emergencyPhone').isNotEmpty &&
        normalizeRunnerPhone(value('emergencyPhone')) ==
            normalizeRunnerPhone(value('phone'))) {
      errors['emergencyPhone'] =
          'SĐT khẩn cấp không được trùng SĐT người tham gia.';
    }
    if (!emergencyRelations.contains(value('emergencyRelation'))) {
      errors['emergencyRelation'] = 'Vui lòng chọn mối quan hệ.';
    }
    final codes = (data['medicalCodes'] as List? ?? []).cast<String>();
    if (codes.isEmpty) {
      errors['medicalCodes'] =
          'Chọn ít nhất một mục bệnh lý (hoặc “Không mắc…”).';
    } else if (codes.contains('none') && codes.length > 1) {
      errors['medicalCodes'] =
          'Không chọn “Không mắc bệnh lý đặc biệt” cùng bệnh khác.';
    }
    if (!(codes.length == 1 && codes.first == 'none') && !hasCertificate) {
      errors['healthCert'] = 'Vui lòng đính kèm phiếu khám sức khỏe.';
    }
    if (data['liabilityAccepted'] != true) {
      errors['liabilityAccepted'] = 'Cần chấp nhận điều khoản trách nhiệm.';
    }
  }
  if (step == 3 && data['paymentTermsAccepted'] != true) {
    errors['paymentTermsAccepted'] = 'Cần chấp nhận điều khoản thanh toán.';
  }
  return errors;
}
