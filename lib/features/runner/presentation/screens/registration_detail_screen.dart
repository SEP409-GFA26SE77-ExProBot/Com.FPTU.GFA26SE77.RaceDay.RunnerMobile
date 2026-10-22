import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/runner_widgets.dart';
import 'payment_screen.dart';
import 'registration_form_screen.dart';

class RegistrationDetailScreen extends StatefulWidget {
  final String registrationId;
  final UserEntity user;
  final RunnerRepository repository;
  final bool openPayment;
  const RegistrationDetailScreen({
    super.key,
    required this.registrationId,
    required this.user,
    required this.repository,
    this.openPayment = false,
  });
  @override
  State<RegistrationDetailScreen> createState() =>
      _RegistrationDetailScreenState();
}

class _RegistrationDetailScreenState extends State<RegistrationDetailScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  bool _polling = false, _active = true, _loadingDetails = false;
  int _loadVersion = 0;
  Registration? registration;
  RaceDetail? race;
  RunnerPayment? payment;
  String? error, extraError, refreshError;
  bool loading = true, didAutoOpen = false;
  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
  }

  Future<void> _refreshStatus({bool force = false}) async {
    if (!mounted ||
        !_active ||
        loading ||
        _polling ||
        ModalRoute.of(context)?.isCurrent != true ||
        (!force &&
            !(registration?.status == 'pending_approval' ||
                (registration?.status == 'confirmed' &&
                    (!registration!.hasTicket ||
                        registration!.checkedInAt == null))))) {
      return;
    }
    _polling = true;
    final version = _loadVersion;
    try {
      final updated = await widget.repository.registration(
        widget.registrationId,
      );
      if (mounted && version == _loadVersion) {
        setState(() {
          registration = updated;
          refreshError = null;
        });
      }
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(
          () => refreshError =
              'Chưa cập nhật được trạng thái. Đang hiển thị thông tin gần nhất; vui lòng kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refreshStatus(force: true);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loadingDetails) return;
    _loadingDetails = true;
    _loadVersion++;
    setState(() {
      loading = true;
      error = null;
      extraError = null;
      refreshError = null;
    });
    try {
      registration = await widget.repository.registration(
        widget.registrationId,
      );
      try {
        race = await widget.repository.event(registration!.eventId);
      } catch (_) {
        extraError =
            'Thông tin giải hiện không khả dụng. Bạn vẫn có thể xem hồ sơ và vé đã cấp.';
      }
      try {
        final list =
            (await widget.repository.payments())
                .where((p) => p.registrationId == widget.registrationId)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        payment = list.where((p) => p.paid).firstOrNull ?? list.firstOrNull;
      } catch (_) {
        extraError =
            'Chưa tải được thông tin thanh toán. Vui lòng kiểm tra lại trước khi thanh toán.';
      }
    } catch (e) {
      if (registration == null) {
        error = e.toString();
      } else {
        refreshError =
            'Chưa cập nhật được trạng thái. Đang hiển thị thông tin gần nhất; vui lòng kiểm tra kết nối và thử lại.';
      }
    }
    _loadingDetails = false;
    if (!mounted) return;
    setState(() => loading = false);
    if (widget.openPayment &&
        !didAutoOpen &&
        registration?.status == 'pending_payment') {
      didAutoOpen = true;
      await _payment();
    }
  }

  Future<void> _payment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            race != null && registration?.status == 'pending_payment'
            ? RegistrationFormScreen(
                race: race!,
                resumeRegistration: registration,
                user: widget.user,
                repository: widget.repository,
              )
            : PaymentScreen(
                repository: widget.repository,
                registrationId: widget.registrationId,
                user: widget.user,
              ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _resubmit() async {
    final r = race!;
    final distance = r.distances
        .where((d) => d.id == registration!.distanceId)
        .firstOrNull;
    if (distance == null) {
      setState(
        () => extraError = 'Cự ly không còn khả dụng. Vui lòng liên hệ BTC.',
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationFormScreen(
          race: r,
          distance: distance,
          existing: registration,
          user: widget.user,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = registration;
    final reconciliation =
        payment?.status == 'paid' &&
        ['pending_payment', 'cancelled'].contains(r?.status);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đăng ký / Vé')),
      body: loading && r == null
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: RunnerNotice(error!, onRetry: _load))
          : r == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      if (refreshError != null)
                        RunnerNotice(
                          refreshError!,
                          onRetry: loading ? null : _load,
                        ),
                      if (extraError != null)
                        RunnerNotice(extraError!, onRetry: _load),
                      RunnerPanel(
                        title: r.eventName,
                        children: [
                          StatusPill(r.statusLabel),
                          infoLine('Cự ly', r.distanceLabel),
                          infoLine('Mã đăng ký', r.id),
                          infoLine('Giá đã chốt', money(r.price, r.currency)),
                          if (payment?.paid == true)
                            infoLine(
                              payment!.status == 'refunded'
                                  ? 'Đã hoàn tiền'
                                  : 'Đã thanh toán',
                              money(payment!.amount, payment!.currency),
                            ),
                          if (race != null)
                            infoLine('Ngày tổ chức', calendarDate(race!.date)),
                        ],
                      ),
                      if (reconciliation)
                        const RunnerNotice(
                          'Đã nhận thanh toán, đăng ký đang cần xử lý. Vui lòng liên hệ BTC và cung cấp mã đăng ký.',
                        ),
                      if (r.status == 'pending_payment')
                        FilledButton.icon(
                          onPressed: _payment,
                          icon: const Icon(Icons.payment),
                          label: Text(
                            reconciliation
                                ? 'Kiểm tra trạng thái thanh toán'
                                : 'Tiếp tục thanh toán',
                          ),
                        ),
                      if (r.status == 'pending_approval')
                        const RunnerNotice(
                          'Đã thanh toán — chờ BTC duyệt hồ sơ. Trạng thái tự động cập nhật; BIB và QR xuất hiện khi được duyệt.',
                        ),
                      if (r.status == 'rejected') ...[
                        RunnerPanel(
                          title: 'Lý do từ chối',
                          children: [
                            Text(r.rejectionReason ?? 'Vui lòng liên hệ BTC.'),
                          ],
                        ),
                        FilledButton(
                          onPressed: race?.acceptsNow == true
                              ? _resubmit
                              : null,
                          child: const Text('Sửa hồ sơ và nộp lại'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          race?.acceptsNow == true
                              ? 'Giữ nguyên cự ly và giá. Không thanh toán lại.'
                              : 'Giải hiện không nhận nộp lại hồ sơ. Vui lòng liên hệ BTC.',
                        ),
                      ],
                      if (r.status == 'confirmed')
                        RunnerPanel(
                          title: 'Vé tham dự',
                          children: [
                            CheckInStatus(checkedInAt: r.checkedInAt),
                            if (r.checkedInAt == null) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Trạng thái tự cập nhật khi có kết nối. Nếu staff check-in khi mất mạng, kết quả sẽ xuất hiện sau khi staff đồng bộ thành công.',
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (r.hasTicket)
                              Center(
                                child: Column(
                                  children: [
                                    const Text('SỐ BIB'),
                                    Text(
                                      r.bib!,
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 280,
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: QrImageView(
                                          data: r.qrJson!,
                                          backgroundColor: Colors.white,
                                          padding: const EdgeInsets.all(18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      r.checkedInAt == null
                                          ? 'Đưa mã QR này cho staff tại điểm check-in.'
                                          : 'Check-in đã được ghi nhận. Giữ vé để đối chiếu khi cần.',
                                      textAlign: TextAlign.center,
                                    ),
                                    infoLine('Mã vé', r.ticketCode),
                                  ],
                                ),
                              )
                            else
                              const Text(
                                'Vé chưa đủ dữ liệu BIB/QR. Vui lòng tải lại hoặc liên hệ BTC.',
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      RunnerPanel(
                        title: 'Hồ sơ runner',
                        children: [
                          infoLine('Họ tên', r.fullName),
                          infoLine('Email', r.data['email'] as String?),
                          infoLine('Điện thoại', r.data['phone'] as String?),
                          if (r.data['dateOfBirth'] != null)
                            infoLine(
                              'Ngày sinh',
                              calendarDate(r.data['dateOfBirth'] as String?),
                            ),
                          infoLine('Giới tính', r.data['gender'] as String?),
                          infoLine('CCCD/CMND', r.data['idNumber'] as String?),
                          infoLine(
                            'Liên hệ khẩn cấp',
                            r.data['emergencyName'] as String?,
                          ),
                          infoLine(
                            'Điện thoại khẩn cấp',
                            r.data['emergencyPhone'] as String?,
                          ),
                          infoLine(
                            'Chiều cao (cm)',
                            r.data['heightCm']?.toString(),
                          ),
                          infoLine(
                            'Cân nặng (kg)',
                            r.data['weightKg']?.toString(),
                          ),
                          infoLine('Nhóm máu', r.data['bloodType'] as String?),
                          infoLine(
                            'Tình trạng sức khỏe',
                            (r.data['medicalCodes'] as List?)?.join(', '),
                          ),
                          infoLine(
                            'Áo',
                            [
                              r.data['shirtType'],
                              r.data['shirtSize'],
                              r.data['shirtColor'],
                            ].whereType<String>().join(' · '),
                          ),
                          if (r.data['healthCertUrl'] is String)
                            TextButton.icon(
                              onPressed: () => openExternal(
                                context,
                                r.data['healthCertUrl'] as String,
                              ),
                              icon: const Icon(Icons.description_outlined),
                              label: Text(
                                r.data['healthCertFileName'] as String? ??
                                    'Xem giấy khám',
                              ),
                            ),
                        ],
                      ),
                      if (race != null)
                        RunnerPanel(
                          title: 'Liên hệ Ban tổ chức',
                          children: [
                            infoLine('Tên', race!.organizerName),
                            if (race!.organizerEmail.isNotEmpty)
                              TextButton(
                                onPressed: () => openExternal(
                                  context,
                                  'mailto:${race!.organizerEmail}',
                                ),
                                child: Text(race!.organizerEmail),
                              ),
                            if (race!.organizerPhone.isNotEmpty)
                              TextButton(
                                onPressed: () => openExternal(
                                  context,
                                  'tel:${race!.organizerPhone}',
                                ),
                                child: Text(race!.organizerPhone),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
