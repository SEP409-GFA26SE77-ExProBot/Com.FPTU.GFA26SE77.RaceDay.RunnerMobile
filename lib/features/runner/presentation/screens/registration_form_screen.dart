import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../data/registration_draft_store.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../../domain/registration_form_rules.dart';
import '../../domain/registration_form_values.dart';
import '../../domain/registration_validation.dart';
import '../widgets/runner_widgets.dart';
import 'payment_screen.dart';

class RegistrationFormScreen extends StatefulWidget {
  final RaceDetail race;
  final RaceDistance? distance;
  final UserEntity user;
  final RunnerRepository repository;
  final Registration? existing, resumeRegistration;
  const RegistrationFormScreen({
    super.key,
    required this.race,
    this.distance,
    required this.user,
    required this.repository,
    this.existing,
    this.resumeRegistration,
  });
  @override
  State<RegistrationFormScreen> createState() => _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends State<RegistrationFormScreen> {
  static const labels = {
    'fullName': 'Họ và tên *',
    'email': 'Email *',
    'phone': 'Số điện thoại *',
    'dateOfBirth': 'Ngày sinh *',
    'idNumber': 'CCCD/CMND *',
    'bibName': 'Tên trên BIB',
    'emergencyName': 'Người liên hệ khẩn cấp *',
    'emergencyPhone': 'SĐT khẩn cấp *',
  };
  static const steps = [
    'Chọn cự ly',
    'Thông tin cá nhân',
    'Thông tin y tế',
    'Thanh toán',
  ];
  late final fields = {
    for (final key in labels.keys) key: TextEditingController(),
  };
  late final drafts = RegistrationDraftStore(
    widget.user.id ?? widget.user.username,
    widget.race.id,
  );
  final scroll = ScrollController();
  List<String> medical = [];
  Map<String, String> errors = {};
  String? distanceId,
      gender,
      blood,
      shirtSize,
      relation,
      certUrl,
      certName,
      error;
  Uint8List? certBytes;
  Registration? pending;
  bool loading = true,
      busy = false,
      liability = false,
      terms = false,
      uncertain = false;
  int step = 0;
  RaceDistance? get distance =>
      widget.race.distances.where((d) => d.id == distanceId).firstOrNull;
  bool get resubmitting => widget.existing != null;
  bool get reviewingPending => pending != null && !resubmitting;
  bool get editingEnabled => !busy && !reviewingPending;
  bool registrationCheckFailed = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    setState(() {
      loading = true;
      error = null;
      registrationCheckFailed = !resubmitting;
    });
    try {
      final draft = await drafts.read();
      Registration? resume = widget.resumeRegistration;
      if (!resubmitting && resume == null) {
        resume = (await widget.repository.registrations())
            .where(
              (r) =>
                  r.eventId == widget.race.id && r.status == 'pending_payment',
            )
            .firstOrNull;
      }
      if (!resubmitting && resume != null) {
        final saved = await widget.repository.registration(resume.id);
        if (!mounted) return;
        registrationCheckFailed = false;
        if (saved.status == 'cancelled') {
          await _resetCancelled();
        } else if (saved.status != 'pending_payment') {
          await _finish(saved);
        } else {
          _restorePending(saved);
        }
        if (mounted) setState(() => loading = false);
        return;
      }
      registrationCheckFailed = false;
      final profile =
          widget.existing?.data ??
          (draft != null
              ? <String, dynamic>{}
              : (await widget.repository.profile()).fields);
      final data = <String, dynamic>{
        ...profile,
        if (!resubmitting && draft != null) ...draft,
      };
      if (!mounted) return;
      _fill(data, fromProfile: !resubmitting && draft == null);
      distanceId =
          widget.existing?.distanceId ??
          data['distanceId'] as String? ??
          widget.distance?.id;
      if (distance == null) distanceId = null;
      if (resubmitting) {
        liability = true;
        step = 1;
      }
    } catch (e) {
      if (!mounted) return;
      error = registrationCheckFailed
          ? 'Chưa kiểm tra được đơn đăng ký hiện có. Vui lòng thử lại trước khi tiếp tục. $e'
          : 'Chưa tải được hồ sơ. Bạn có thể tự điền thông tin. $e';
      fields['fullName']!.text = widget.user.fullName ?? '';
      fields['email']!.text = widget.user.email ?? '';
    }
    if (mounted) setState(() => loading = false);
  }

  void _fill(Json data, {bool fromProfile = false}) {
    for (final key in fields.keys) {
      fields[key]!.text = data[key]?.toString() ?? '';
    }
    fields['dateOfBirth']!.text = registrationBirthDate(data['dateOfBirth']);
    gender = registrationGender(data['gender'], fromProfile: fromProfile);
    blood = bloodOptions.contains(data['bloodType'])
        ? data['bloodType'] as String
        : null;
    shirtSize = shirtSizes.contains(data['shirtSize'])
        ? data['shirtSize'] as String
        : null;
    relation = emergencyRelations.contains(data['emergencyRelation'])
        ? data['emergencyRelation'] as String
        : null;
    medical = registrationMedicalCodes(data['medicalCodes']);
    certName = data['healthCertFileName'] as String?;
    certUrl = data['healthCertUrl'] as String?;
    liability = data['liabilityAccepted'] == true;
    terms = data['paymentTermsAccepted'] == true;
  }

  Json _data() => {
    'distanceId': distanceId,
    for (final key in fields.keys) key: fields[key]!.text.trim(),
    'gender': gender,
    'bloodType': blood,
    'shirtSize': shirtSize,
    'emergencyRelation': relation,
    'medicalCodes': medical,
    'healthCertUrl': certUrl,
    'healthCertFileName': certUrl == null ? null : certName,
    'liabilityAccepted': liability,
    'paymentTermsAccepted': terms,
  };

  Future<void> _save() => drafts.save(_data());

  void _restorePending(Registration reg) {
    setState(() {
      pending = reg;
      _fill(reg.data);
      // Creating a saved registration requires acceptance; the read DTO omits it.
      liability = true;
      distanceId = reg.distanceId;
      certBytes = null;
      step = 1;
      errors = {};
      error = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _changeStep(int next) {
    setState(() {
      step = next;
      errors = {};
      error = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  bool _validate(int at) {
    final found = validateRunnerStep(
      at,
      _data(),
      hasCertificate: certBytes != null || (certUrl?.isNotEmpty ?? false),
    );
    if (found.isEmpty) return true;
    setState(() {
      step = at;
      errors = found;
      error = 'Vui lòng kiểm tra các thông tin được đánh dấu.';
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    return false;
  }

  Future<void> _next() async {
    if (!_validate(step)) return;
    await _save();
    if (mounted) _changeStep(step + 1);
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = runnerBirthDateAtAge(now, 100);
    final last = runnerBirthDateAtAge(now, 5);
    final saved = DateTime.tryParse(fields['dateOfBirth']!.text);
    final chosen = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate:
          saved != null && !saved.isBefore(first) && !saved.isAfter(last)
          ? saved
          : DateTime(now.year - 25),
    );
    if (chosen != null && mounted) {
      setState(() {
        fields['dateOfBirth']!.text = DateFormat('yyyy-MM-dd').format(chosen);
        errors.remove('dateOfBirth');
      });
    }
  }

  Future<void> _chooseFile() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result.isEmpty) return;
      final file = result.single;
      final size = await file.length();
      final sizeError = size == null
          ? null
          : validateHealthFile(file.name, size);
      if (sizeError != null) throw AppException(sizeError);
      final bytes = await file.readAsBytes();
      final invalid = validateHealthFile(file.name, bytes.length);
      if (invalid != null) throw AppException(invalid);
      if (!mounted) return;
      setState(() {
        certName = file.name;
        certBytes = bytes;
        certUrl = null;
        errors.remove('healthCert');
      });
    } catch (e) {
      if (mounted) setState(() => errors['healthCert'] = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Registration?> _recover() async =>
      (await widget.repository.registrations())
          .where(
            (r) =>
                r.eventId == widget.race.id &&
                r.distanceId == distanceId &&
                r.status != 'cancelled',
          )
          .firstOrNull;

  Future<void> _finish(Registration reg) async {
    await drafts.clear();
    if (!mounted) return;
    setState(() => busy = false);
    Navigator.pop(context, reg);
  }

  Future<void> _resetCancelled() async {
    await drafts.clear();
    if (!mounted) return;
    setState(() {
      for (final c in fields.values) {
        c.clear();
      }
      distanceId = null;
      gender = null;
      blood = null;
      shirtSize = null;
      relation = null;
      medical = [];
      certName = null;
      certUrl = null;
      certBytes = null;
      pending = null;
      liability = false;
      terms = false;
      uncertain = false;
      registrationCheckFailed = false;
    });
    _changeStep(0);
  }

  Future<void> _pay(Registration reg) async {
    if (reg.status == 'cancelled') {
      await _resetCancelled();
      return;
    }
    if (reg.status != 'pending_payment') {
      await _finish(reg);
      return;
    }
    if (!mounted) return;
    _restorePending(reg);
    setState(() => busy = false);
    final outcome = await Navigator.push<PaymentOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          repository: widget.repository,
          registrationId: reg.id,
          user: widget.user,
        ),
      ),
    );
    if (!mounted) return;
    if (outcome == PaymentOutcome.cancelled) {
      await _resetCancelled();
    } else if (outcome == PaymentOutcome.paid) {
      await _finish(await widget.repository.registration(reg.id));
    } else {
      final saved = await widget.repository.registration(reg.id);
      if (!mounted) return;
      if (saved.status == 'cancelled') {
        await _resetCancelled();
        return;
      }
      if (saved.status != 'pending_payment') {
        await _finish(saved);
        return;
      }
      _restorePending(saved);
    }
  }

  Future<void> _continuePayment() async {
    if (busy || pending == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await _pay(await widget.repository.registration(pending!.id));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _submit() async {
    if (busy || loading || registrationCheckFailed) return;
    if (reviewingPending) {
      await _continuePayment();
      return;
    }
    for (var i = resubmitting ? 1 : 0; i < (resubmitting ? 3 : 4); i++) {
      if (!_validate(i)) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (uncertain) {
        final recovered = resubmitting
            ? await widget.repository.registration(widget.existing!.id)
            : await _recover();
        if (recovered != null &&
            (!resubmitting || recovered.status != 'rejected')) {
          if (resubmitting) {
            await _finish(recovered);
          } else {
            await _pay(recovered);
          }
          return;
        }
      }
      final fresh = await widget.repository.event(widget.race.id);
      if (!fresh.acceptsNow) throw AppException(fresh.registrationMessage);
      if (!resubmitting &&
          !fresh.distances.any((d) => d.id == distanceId && d.hasSlot)) {
        throw AppException('Cự ly đã hết suất. Vui lòng chọn cự ly khác.');
      }
      if (certBytes != null) {
        final uploaded = await widget.repository.upload(certName!, certBytes!);
        certUrl = uploaded['fileUrl'] as String;
        certName = uploaded['fileName'] as String? ?? certName;
        certBytes = null;
      }
      await _save();
      final body = _data()..remove('paymentTermsAccepted');
      for (final key in ['heightCm', 'weightKg', 'shirtType', 'shirtColor']) {
        if (widget.existing?.data[key] != null) {
          body[key] = widget.existing!.data[key];
        }
      }
      uncertain = true;
      final reg = resubmitting
          ? await widget.repository.resubmit(widget.existing!.id, body)
          : await widget.repository.createRegistration(widget.race.id, body);
      uncertain = false;
      if (resubmitting) {
        await _finish(reg);
      } else {
        await _pay(reg);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      if (uncertain) {
        try {
          final recovered = resubmitting
              ? await widget.repository.registration(widget.existing!.id)
              : await _recover();
          if (recovered != null &&
              (!resubmitting || recovered.status != 'rejected')) {
            uncertain = false;
            if (resubmitting) {
              await _finish(recovered);
            } else {
              await _pay(recovered);
            }
          }
        } catch (_) {
          /* Keep the form; next submit first checks the saved order. */
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: Key('field-$key'),
      controller: fields[key],
      enabled: editingEnabled,
      maxLength: key == 'bibName' ? 40 : null,
      readOnly: key == 'dateOfBirth',
      onTap: key == 'dateOfBirth' ? _pickDate : null,
      onChanged: (_) => setState(() => errors.remove(key)),
      keyboardType: key.toLowerCase().contains('phone')
          ? TextInputType.phone
          : key == 'email'
          ? TextInputType.emailAddress
          : key == 'idNumber'
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: labels[key],
        errorText: errors[key],
        errorMaxLines: 3,
        helperText: key == 'idNumber'
            ? 'Nếu chưa đủ tuổi, có thể điền CCCD/CMND của người giám hộ hoặc người liên hệ khẩn cấp (9 hoặc 12 chữ số).'
            : null,
        helperMaxLines: 4,
        border: const OutlineInputBorder(),
        suffixIcon: key == 'dateOfBirth'
            ? const Icon(Icons.calendar_month)
            : null,
      ),
    ),
  );
  Widget _dropdown(
    String key,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> change, {
    Map<String, String>? display,
    bool allowEmpty = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key-$value'),
      initialValue: allowEmpty ? value ?? '' : value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        errorText: errors[key],
        border: const OutlineInputBorder(),
      ),
      items: [
        if (allowEmpty)
          const DropdownMenuItem(
            value: '',
            child: Text('Để trống / Chọn size'),
          ),
        ...options.map(
          (o) => DropdownMenuItem(value: o, child: Text(display?[o] ?? o)),
        ),
      ],
      onChanged: !editingEnabled
          ? null
          : (v) => setState(() {
              change(v == '' ? null : v);
              errors.remove(key);
            }),
    ),
  );
  Widget _error(String key) => errors[key] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(errors[key]!, style: const TextStyle(color: Colors.red)),
        );

  Widget _content() {
    if (step == 0) {
      return RunnerPanel(
        title: 'Chọn cự ly',
        children: [
          for (final d in widget.race.distances)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                key: Key('distance-${d.id}'),
                onTap: !editingEnabled || !d.hasSlot
                    ? null
                    : () => setState(() {
                        distanceId = d.id;
                        errors.remove('distanceId');
                      }),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: distanceId == d.id
                          ? Colors.deepOrange
                          : Colors.grey.shade300,
                      width: distanceId == d.id ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        distanceId == d.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.name} · ${d.km} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(money(d.estimatedPrice, d.currency)),
                            if (d.phaseName != null)
                              Text(
                                d.phaseName!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            Text(
                              !d.hasSlot
                                  ? 'Hết suất'
                                  : d.capacity <= 0
                                  ? 'Không giới hạn'
                                  : 'Còn ${d.capacity - d.registered} suất',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          _error('distanceId'),
        ],
      );
    }
    if (step == 1) {
      return Column(
        children: [
          RunnerPanel(
            title: 'Thông tin cá nhân',
            children: [
              _field('fullName'),
              _field('email'),
              _field('phone'),
              _dropdown(
                'gender',
                'Giới tính *',
                gender,
                ['Male', 'Female', 'Other'],
                (v) => gender = v,
                display: {'Male': 'Nam', 'Female': 'Nữ', 'Other': 'Khác'},
              ),
              _field('dateOfBirth'),
              _field('idNumber'),
            ],
          ),
          RunnerPanel(
            title: 'Thông tin bổ sung',
            children: [
              _dropdown(
                'shirtSize',
                'Size áo (tùy chọn)',
                shirtSize,
                shirtSizes,
                (v) => shirtSize = v,
                allowEmpty: true,
              ),
              _field('bibName'),
            ],
          ),
        ],
      );
    }
    if (step == 2) {
      return Column(
        children: [
          RunnerPanel(
            title: 'Thông tin y tế',
            children: [
              _dropdown(
                'bloodType',
                'Nhóm máu *',
                blood,
                bloodOptions,
                (v) => blood = v,
              ),
              const Text(
                'Bệnh lý / tình trạng sức khỏe *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final entry in medicalOptions.entries)
                CheckboxListTile(
                  key: Key('medical-${entry.key}'),
                  contentPadding: EdgeInsets.zero,
                  value: medical.contains(entry.key),
                  title: Text(entry.value),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: !editingEnabled
                      ? null
                      : (_) => setState(() {
                          medical = toggleMedical(medical, entry.key);
                          errors.remove('medicalCodes');
                        }),
                ),
              _error('medicalCodes'),
              const Divider(),
              Text(
                medical.length == 1 && medical.first == 'none'
                    ? 'Phiếu khám sức khỏe (tùy chọn)'
                    : 'Phiếu khám sức khỏe *',
              ),
              const Text(
                'PDF, JPG, PNG · Tối đa 5MB',
                style: TextStyle(fontSize: 12),
              ),
              if (certName != null) Text(certName!),
              OutlinedButton.icon(
                key: const Key('health-file'),
                onPressed: editingEnabled ? _chooseFile : null,
                icon: const Icon(Icons.attach_file),
                label: Text(certName == null ? 'Chọn file' : 'Đổi file'),
              ),
              _error('healthCert'),
            ],
          ),
          RunnerPanel(
            title: 'Liên hệ khẩn cấp',
            children: [
              _field('emergencyName'),
              _field('emergencyPhone'),
              _dropdown(
                'emergencyRelation',
                'Mối quan hệ *',
                relation,
                emergencyRelations,
                (v) => relation = v,
              ),
            ],
          ),
          RunnerPanel(
            title: 'Điều khoản trách nhiệm',
            children: [
              CheckboxListTile(
                key: const Key('liability'),
                contentPadding: EdgeInsets.zero,
                value: liability,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: !editingEnabled
                    ? null
                    : (v) => setState(() {
                        liability = v ?? false;
                        errors.remove('liabilityAccepted');
                      }),
                title: const Text(
                  'Tôi chấp nhận điều khoản trách nhiệm, hiểu rủi ro khi tham gia giải chạy và xác nhận đủ sức khỏe để thi đấu. *',
                ),
              ),
              _error('liabilityAccepted'),
            ],
          ),
        ],
      );
    }
    return Column(
      children: [
        RunnerPanel(
          title: 'Kiểm tra thông tin',
          children: [
            infoLine('Giải chạy', widget.race.name),
            infoLine(
              'Cự ly',
              distance == null
                  ? null
                  : '${distance!.name} · ${distance!.km} km',
            ),
            for (final key in fields.keys)
              infoLine(labels[key]!.replaceAll(' *', ''), fields[key]!.text),
            infoLine(
              'Giới tính',
              {'Male': 'Nam', 'Female': 'Nữ', 'Other': 'Khác'}[gender],
            ),
            infoLine('Size áo', shirtSize),
            infoLine('Nhóm máu', blood),
            infoLine('Mối quan hệ', relation),
            infoLine(
              'Sức khỏe',
              medical.map((c) => medicalOptions[c] ?? c).join(', '),
            ),
            infoLine('Phiếu khám', certName),
            infoLine(
              'Trách nhiệm',
              liability ? 'Đã chấp nhận' : 'Chưa chấp nhận',
            ),
          ],
        ),
        RunnerPanel(
          title: 'Phương thức thanh toán',
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.qr_code_2),
              title: Text('Quét mã QR ngân hàng (PayOS)'),
            ),
            Text(
              money(
                reviewingPending ? pending!.price : distance?.estimatedPrice,
                reviewingPending
                    ? pending!.currency
                    : distance?.currency ?? 'VND',
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              reviewingPending
                  ? 'Tiếp tục thanh toán sử dụng thông tin và số tiền đã lưu trong đơn.'
                  : 'Giá tham khảo. Sau khi bấm Thanh toán, hệ thống tạo đơn và mở mã QR với số tiền đã chốt.',
            ),
            if (!reviewingPending)
              CheckboxListTile(
                key: const Key('payment-terms'),
                contentPadding: EdgeInsets.zero,
                value: terms,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: !editingEnabled
                    ? null
                    : (v) => setState(() {
                        terms = v ?? false;
                        errors.remove('paymentTermsAccepted');
                      }),
                title: const Text(
                  'Tôi đã đọc, hiểu và chấp nhận quy định sự kiện cùng điều khoản thanh toán của RaceDay. *',
                ),
              ),
            if (!reviewingPending) _error('paymentTermsAccepted'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          resubmitting ? 'Chỉnh sửa & nộp lại' : 'Đăng ký tham gia giải',
        ),
      ),
      bottomNavigationBar: loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (step > (resubmitting ? 1 : 0)) ...[
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (!reviewingPending) await _save();
                                if (mounted) _changeStep(step - 1);
                              },
                        child: const Text('Quay lại'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        key: Key(
                          reviewingPending ? 'resume-payment' : 'form-next',
                        ),
                        onPressed: busy || registrationCheckFailed
                            ? null
                            : reviewingPending
                            ? _continuePayment
                            : step < (resubmitting ? 2 : 3)
                            ? _next
                            : _submit,
                        child: Text(
                          busy
                              ? 'Đang xử lý…'
                              : reviewingPending
                              ? 'Tiếp tục thanh toán'
                              : step < (resubmitting ? 2 : 3)
                              ? 'Tiếp tục'
                              : resubmitting
                              ? 'Nộp lại hồ sơ'
                              : 'Thanh toán',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      widget.race.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (!resubmitting)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            Expanded(
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: i <= step
                                        ? Colors.deepOrange
                                        : Colors.grey.shade200,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: i <= step
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    steps[i],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (busy) const LinearProgressIndicator(),
                    if (error != null)
                      RunnerNotice(
                        error!,
                        onRetry: registrationCheckFailed ? _prefill : null,
                      ),
                    if (pending != null && !resubmitting)
                      RunnerPanel(
                        title: 'Đơn đang chờ thanh toán',
                        children: [
                          Text(
                            'Cự ly: ${pending!.distanceLabel}. Đây là thông tin đã lưu trong đơn và không thể sửa tại đây. Tiếp tục thanh toán sẽ dùng đơn này. Nếu cần đổi thông tin, hãy hủy đơn chưa thanh toán ở màn hình thanh toán rồi đăng ký lại.',
                          ),
                          if (step < 3)
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _changeStep(step + 1),
                              child: const Text('Xem tiếp thông tin đã lưu'),
                            ),
                        ],
                      ),
                    _content(),
                  ],
                ),
              ),
            ),
    ),
  );
}
