import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../domain/runner_repository.dart';
import '../controllers/payment_controller.dart';
import '../widgets/runner_widgets.dart';

enum PaymentOutcome { paid, cancelled }

class PaymentScreen extends StatefulWidget {
  final RunnerRepository repository;
  final String registrationId;
  final UserEntity user;
  const PaymentScreen({
    super.key,
    required this.repository,
    required this.registrationId,
    required this.user,
  });
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  late final PaymentController controller;
  Timer? _poll, _success;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    controller = PaymentController(
      repository: widget.repository,
      registrationId: widget.registrationId,
      userId: widget.user.id ?? widget.user.username,
    )..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    controller.refresh(prepareCheckout: true);
    _poll = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (_active && ModalRoute.of(context)?.isCurrent == true) {
        controller.poll();
      }
    });
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!controller.busy &&
        controller.verified &&
        [
          'pending_approval',
          'confirmed',
        ].contains(controller.registration?.status) &&
        _success == null &&
        Navigator.canPop(context)) {
      _success = Timer(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.pop(context, PaymentOutcome.paid);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) controller.refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _success?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hủy thanh toán?'),
        content: const Text(
          'Hủy đơn chưa thanh toán và xóa form để đăng ký lại. Nếu vừa chuyển tiền, hãy kiểm tra thanh toán trước.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (ok == true && await controller.cancel() && mounted) {
      Navigator.pop(context, PaymentOutcome.cancelled);
    }
  }

  Widget _transfer(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(child: infoLine(label, value)),
        IconButton(
          tooltip: 'Sao chép $label',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Đã sao chép $label')));
            }
          },
          icon: const Icon(Icons.copy, size: 20),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = controller.registration;
    final p = controller.payment;
    final pending = r?.status == 'pending_payment' && p?.status == 'pending';
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán VietQR')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.error != null)
                RunnerNotice(
                  controller.error!,
                  onRetry: () => controller.refresh(),
                ),
              if (r != null) ...[
                RunnerPanel(
                  title: r.eventName,
                  children: [
                    StatusPill(r.statusLabel),
                    infoLine('Cự ly', r.distanceLabel),
                    infoLine('Runner', r.fullName),
                    infoLine('Mã đăng ký', r.id),
                    infoLine('Tổng thanh toán', money(r.price, r.currency)),
                  ],
                ),
                if (controller.needsReconciliation)
                  const RunnerNotice(
                    'Đã nhận thanh toán, đăng ký đang cần xử lý. Vui lòng liên hệ Ban tổ chức và cung cấp mã đăng ký.',
                  ),
                if (r.status == 'pending_approval')
                  const RunnerNotice(
                    'Đã thanh toán — chờ BTC duyệt hồ sơ. BIB và QR sẽ xuất hiện trong vé sau khi được duyệt.',
                  ),
                if (r.status == 'confirmed')
                  const RunnerNotice(
                    'Vé đã sẵn sàng. Xem BIB và QR trong chi tiết đăng ký.',
                  ),
                if (r.status == 'cancelled' && !controller.needsReconciliation)
                  const RunnerNotice('Đăng ký đã được hủy.'),
                if (pending && p!.qrCode?.isNotEmpty == true)
                  RunnerPanel(
                    title: 'Quét mã để thanh toán',
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: QrImageView(
                              key: const Key('payment-qr'),
                              data: p.qrCode!,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Mở ứng dụng ngân hàng để quét VietQR hoặc chuyển khoản theo thông tin bên dưới.',
                      ),
                      _transfer('Chủ tài khoản', p.accountName),
                      _transfer('Số tài khoản', p.accountNumber),
                      _transfer('Mã ngân hàng (BIN)', p.bin),
                      _transfer('Số tiền (VND)', p.amount.toString()),
                      _transfer('Nội dung chuyển khoản', p.transferDescription),
                    ],
                  ),
                if (pending &&
                    p!.qrCode?.isNotEmpty != true &&
                    p.checkoutUrl != null)
                  FilledButton.icon(
                    onPressed: controller.canPay
                        ? () => openExternal(context, p.checkoutUrl!)
                        : null,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở PayOS'),
                  ),
                if (pending)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Đang chờ thanh toán · Tự động kiểm tra mỗi 3,5 giây.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (controller.isMock && pending) ...[
                  OutlinedButton.icon(
                    key: const Key('mock-pay'),
                    onPressed: controller.canPay
                        ? controller.testPayment
                        : null,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Test thanh toán thành công'),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Chế độ thử nghiệm — không chuyển tiền thật',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => controller.refresh(prepareCheckout: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kiểm tra thanh toán'),
                ),
                if (controller.verified &&
                    r.status == 'pending_payment' &&
                    p?.paid != true)
                  TextButton(
                    onPressed: controller.busy ? null : _cancel,
                    child: const Text('Hủy thanh toán'),
                  ),
                if (r.status != 'pending_payment')
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      r.status == 'cancelled'
                          ? PaymentOutcome.cancelled
                          : PaymentOutcome.paid,
                    ),
                    child: const Text('Về chi tiết đăng ký'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
