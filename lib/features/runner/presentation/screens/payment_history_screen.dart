import 'package:flutter/material.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';
import 'registration_detail_screen.dart';

String paymentStatus(dynamic value) => switch (value) {
  'pending' => 'Chờ thanh toán',
  'paid' => 'Đã thanh toán',
  'failed' => 'Thất bại',
  'cancelled' => 'Đã hủy',
  'expired' => 'Hết hạn',
  'refunded' => 'Đã hoàn tiền',
  _ => value.toString(),
};
String refundStatus(dynamic value) => switch (value) {
  'requested' => 'Chờ duyệt',
  'processing' => 'Đang xử lý',
  'refunded' => 'Đã hoàn tiền',
  'rejected' => 'Đã từ chối',
  _ => value.toString(),
};

class PaymentHistoryScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final RunnerRepository repository;
  final UserEntity user;
  const PaymentHistoryScreen({
    super.key,
    required this.api,
    required this.repository,
    required this.user,
  });
  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  int revision = 0;
  Future<(List<Json>, List<Json>)> load() async {
    final data = await Future.wait([
      widget.api.payments(),
      widget.api.refunds(),
    ]);
    final payments = data[0]
      ..sort(
        (a, b) => (b['createdAt'] ?? b['createdAtUtc'] ?? '')
            .toString()
            .compareTo((a['createdAt'] ?? a['createdAtUtc'] ?? '').toString()),
      );
    return (payments, data[1]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thanh toán và hoàn tiền')),
    body: ActivityResource<(List<Json>, List<Json>)>(
      key: ValueKey(revision),
      load: load,
      builder: (data, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật giao dịch'),
          ),
          if (data.$1.isEmpty) const RunnerNotice('Bạn chưa có giao dịch.'),
          ...data.$1.map((p) {
            final refund = data.$2
                .where((r) => r['paymentId'] == p['id'])
                .firstOrNull;
            final registrationId = p['registrationId'] as String?;
            return RunnerPanel(
              title: p['eventName'] as String? ?? 'Giao dịch ${p['id']}',
              children: [
                StatusPill(paymentStatus(p['status'])),
                infoLine('Mã giao dịch', p['id'] as String?),
                infoLine('Cự ly', p['distanceName'] as String?),
                infoLine(
                  'Số tiền',
                  money(p['amount'] as num?, p['currency'] as String? ?? 'VND'),
                ),
                infoLine(
                  'Ngày tạo',
                  localTime(
                    DateTime.tryParse(
                      (p['createdAt'] ?? p['createdAtUtc'])?.toString() ?? '',
                    ),
                  ),
                ),
                if (refund != null) ...[
                  const Divider(),
                  Text('Yêu cầu hoàn: ${refundStatus(refund['status'])}'),
                  infoLine('Lý do', refund['reason'] as String?),
                  infoLine('Số tiền đề nghị', money(refund['amount'] as num?)),
                  infoLine('Phản hồi', refund['rejectReason'] as String?),
                ],
                if (registrationId != null)
                  TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegistrationDetailScreen(
                            registrationId: registrationId,
                            user: widget.user,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      if (mounted) setState(() => revision++);
                    },
                    child: Text(
                      p['status'] == 'pending'
                          ? 'Tiếp tục / kiểm tra thanh toán'
                          : 'Xem đăng ký',
                    ),
                  ),
                if (p['status'] == 'paid' &&
                    registrationId != null &&
                    (refund == null || refund['status'] == 'rejected'))
                  OutlinedButton(
                    onPressed: () async {
                      final sent = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RefundScreen(
                            api: widget.api,
                            paymentId: p['id'] as String,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      if (mounted && sent == true) setState(() => revision++);
                    },
                    child: const Text('Yêu cầu hoàn do lỗi hệ thống'),
                  ),
              ],
            );
          }),
        ],
      ),
    ),
  );
}

class RefundScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final String paymentId;
  final RunnerRepository? repository;
  const RefundScreen({
    super.key,
    required this.api,
    required this.paymentId,
    this.repository,
  });
  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final reason = TextEditingController(), evidence = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    evidence.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final links = evidence.text.trim();
      final text =
          reason.text.trim() + (links.isEmpty ? '' : '\n\nĐính kèm:\n$links');
      if (text.length > 1000) {
        throw Exception('Tổng nội dung và liên kết tối đa 1000 ký tự.');
      }
      await widget.api.requestRefund(widget.paymentId, text);
      if (mounted) {
        activityMessage(context, 'Đã gửi yêu cầu. Chờ xác minh và duyệt.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> attach() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final links = evidence.text
          .split(RegExp(r'\s+'))
          .where((v) => v.isNotEmpty)
          .toList();
      if (links.length >= 3) throw Exception('Tối đa 3 bằng chứng.');
      final url = await uploadEvidence(widget.repository!);
      if (mounted && url != null) evidence.text = [...links, url].join('\n');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yêu cầu hoàn tiền')),
    body: ActivityResource<Json>(
      load: () => widget.api.refundQuote(widget.paymentId),
      builder: (quote, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RunnerPanel(
            title: 'Chính sách hoàn tiền',
            children: [
              Text(
                quote['policyNote'] as String? ??
                    'Chỉ xem xét hoàn do lỗi hệ thống sau khi xác minh. Không hoàn vì lý do cá nhân.',
              ),
              infoLine('Đã thanh toán', money(quote['paidAmount'] as num?)),
              infoLine('Số tiền đề nghị', money(quote['refundAmount'] as num?)),
              const Text('Số tiền đề nghị chưa phải khoản hoàn đã được duyệt.'),
            ],
          ),
          Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: reason,
                  enabled: !busy,
                  maxLength: 1000,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả lỗi hệ thống',
                  ),
                  validator: (v) =>
                      v!.trim().length < 20 ? 'Mô tả ít nhất 20 ký tự.' : null,
                ),
                TextFormField(
                  controller: evidence,
                  enabled: !busy,
                  maxLength: 700,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Liên kết bằng chứng (không bắt buộc)',
                  ),
                  validator: (v) {
                    final links = v!
                        .split(RegExp(r'\s+'))
                        .where((l) => l.isNotEmpty);
                    return links.any((l) {
                          final uri = Uri.tryParse(l);
                          return uri == null ||
                              !['http', 'https'].contains(uri.scheme) ||
                              uri.host.isEmpty;
                        })
                        ? 'Nhập liên kết HTTP/HTTPS hợp lệ.'
                        : null;
                  },
                ),
              ],
            ),
          ),
          if (widget.repository != null)
            OutlinedButton.icon(
              onPressed: busy ? null : attach,
              icon: const Icon(Icons.attach_file),
              label: const Text('Tải file bằng chứng'),
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: busy ? null : send,
            child: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu xác minh'),
          ),
        ],
      ),
    ),
  );
}
