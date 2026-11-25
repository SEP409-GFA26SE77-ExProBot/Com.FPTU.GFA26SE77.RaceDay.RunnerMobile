import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_repository.dart';
import 'runner_widgets.dart';

class ActivityResource<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T data, VoidCallback reload) builder;
  const ActivityResource({
    super.key,
    required this.load,
    required this.builder,
  });
  @override
  State<ActivityResource<T>> createState() => _ActivityResourceState<T>();
}

class _ActivityResourceState<T> extends State<ActivityResource<T>> {
  late Future<T> future = widget.load();
  void reload() => setState(() => future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: RunnerNotice(snapshot.error.toString(), onRetry: reload),
        );
      }
      return widget.builder(snapshot.data as T, reload);
    },
  );
}

class ActivityPager extends StatelessWidget {
  final ActivityPage data;
  final ValueChanged<int> onPage;
  const ActivityPager({super.key, required this.data, required this.onPage});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: data.page > 1 ? () => onPage(data.page - 1) : null,
        tooltip: 'Trang trước',
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Trang ${data.page} · ${data.total} mục'),
      IconButton(
        onPressed: data.hasMore ? () => onPage(data.page + 1) : null,
        tooltip: 'Trang sau',
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

void activityMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<String?> uploadEvidence(RunnerRepository repository) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
  );
  if (file == null) return null;
  final length = await file.length();
  if (length != null && length > 10 * 1024 * 1024) {
    throw Exception('File bằng chứng tối đa 10MB.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw Exception('File bằng chứng phải có dữ liệu và tối đa 10MB.');
  }
  final uploaded = await repository.upload(file.name, bytes);
  return mediaUrl(uploaded['fileUrl'] as String);
}

Future<void> saveImage(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  final extension = imageExtension(bytes);
  final uri = await FilePicker.saveFile(
    fileName: '$filename.$extension',
    bytes: bytes,
    mimeType: 'image/${extension == 'jpg' ? 'jpeg' : extension}',
  );
  if (context.mounted && uri != null) activityMessage(context, 'Đã lưu ảnh.');
}

String imageExtension(Uint8List bytes) {
  if (bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8) return 'jpg';
  if (bytes.length >= 4 && bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'webp';
  }
  return 'png';
}

class ActivityImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const ActivityImage(this.url, {super.key, this.fit = BoxFit.contain});
  @override
  Widget build(BuildContext context) => Image.network(
    mediaUrl(url),
    fit: fit,
    cacheWidth: fit == BoxFit.cover ? 800 : 2048,
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator()),
    errorBuilder: (_, _, _) =>
        const Center(child: Text('Không tải được ảnh. Hãy thử lại.')),
  );
}

class ActivityReasonDialog extends StatefulWidget {
  final String title;
  final int minLength, maxLength;
  final Future<void> Function(String reason) submit;
  const ActivityReasonDialog({
    super.key,
    required this.title,
    required this.submit,
    this.minLength = 1,
    this.maxLength = 1000,
  });
  @override
  State<ActivityReasonDialog> createState() => _ActivityReasonDialogState();
}

class _ActivityReasonDialogState extends State<ActivityReasonDialog> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.submit(reason.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: reason,
                enabled: !busy,
                maxLength: widget.maxLength,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Lý do'),
                validator: (v) => (v?.trim().length ?? 0) < widget.minLength
                    ? 'Nhập ít nhất ${widget.minLength} ký tự.'
                    : null,
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: busy ? null : send,
          child: Text(busy ? 'Đang gửi…' : 'Gửi'),
        ),
      ],
    ),
  );
}
