import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

String money(num? n, [String currency = 'VND']) => n == null
    ? 'Chưa có giá'
    : NumberFormat.currency(
        locale: 'vi_VN',
        symbol: currency == 'VND' ? 'đ' : currency,
        decimalDigits: 0,
      ).format(n);
String calendarDate(String? raw) {
  final d = DateTime.tryParse(raw ?? '');
  return d == null ? 'Chưa cập nhật' : DateFormat('dd/MM/yyyy').format(d);
}

String localTime(DateTime? d) => d == null
    ? 'Chưa cập nhật'
    : DateFormat('HH:mm · dd/MM/yyyy').format(d.toLocal());
String shortTime(String? s) =>
    s == null || s.length < 5 ? '' : s.substring(0, 5);

class RunnerPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const RunnerPanel({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

Widget infoLine(String label, String? value) {
  if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 3),
        SelectableText(value, style: const TextStyle(fontSize: 15)),
      ],
    ),
  );
}

class RunnerNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const RunnerNotice(this.message, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String text;
  const StatusPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class CheckInStatus extends StatelessWidget {
  final DateTime? checkedInAt;
  const CheckInStatus({super.key, required this.checkedInAt});

  @override
  Widget build(BuildContext context) {
    final checked = checkedInAt != null;
    final color = checked ? Colors.green.shade800 : Colors.orange.shade900;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: checked ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(checked ? Icons.check_circle : Icons.schedule, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checked ? 'Đã check-in' : 'Chưa check-in',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                if (checked)
                  Text(localTime(checkedInAt), style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RaceImage extends StatelessWidget {
  final String? url;
  final double height;
  const RaceImage(this.url, {super.key, this.height = 200});
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: AppColors.primaryLight,
      child: const Icon(
        Icons.directions_run,
        size: 64,
        color: AppColors.primary,
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

Future<void> openExternal(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (!['http', 'https', 'mailto', 'tel'].contains(uri.scheme)) {
      throw const FormatException();
    }
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok) throw const FormatException();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được liên kết. Vui lòng thử lại.'),
        ),
      );
    }
  }
}
