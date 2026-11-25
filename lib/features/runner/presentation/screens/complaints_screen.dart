import 'package:flutter/material.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';

String complaintStatus(dynamic s) => switch (s.toString().toLowerCase()) {
  'accepted' => 'Đã chấp nhận',
  'rejected' => 'Đã từ chối',
  _ => 'Chờ xử lý',
};

class ComplaintsScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final RunnerRepository repository;
  const ComplaintsScreen({
    super.key,
    required this.api,
    required this.repository,
  });
  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  int page = 1, revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khiếu nại của tôi')),
    floatingActionButton: FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: const Text('Gửi khiếu nại'),
      onPressed: () async {
        final sent = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateComplaintScreen(
              api: widget.api,
              repository: widget.repository,
            ),
          ),
        );
        if (mounted && sent == true) {
          setState(() {
            page = 1;
            revision++;
          });
        }
      },
    ),
    body: ActivityResource<ActivityPage>(
      key: ValueKey('$page:$revision'),
      load: () => widget.api.complaints(page: page),
      builder: (data, reload) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại'),
          ),
          if (data.items.isEmpty) const RunnerNotice('Bạn chưa có khiếu nại.'),
          ...data.items.map(
            (r) => Card(
              child: ListTile(
                title: Text(r['title'] as String),
                subtitle: Text(
                  '${r['eventName']} · ${complaintStatus(r['status'])}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComplaintDetailScreen(
                      api: widget.api,
                      id: r['id'] as String,
                    ),
                  ),
                ),
              ),
            ),
          ),
          ActivityPager(data: data, onPage: (v) => setState(() => page = v)),
        ],
      ),
    ),
  );
}

class ComplaintDetailScreen extends StatelessWidget {
  final RunnerActivityApi api;
  final String id;
  const ComplaintDetailScreen({super.key, required this.api, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết khiếu nại')),
    body: ActivityResource<Json>(
      load: () => api.complaint(id),
      builder: (r, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật phản hồi'),
          ),
          RunnerPanel(
            title: r['title'] as String,
            children: [
              StatusPill(complaintStatus(r['status'])),
              infoLine('Giải', r['eventName'] as String?),
              infoLine('Cự ly', r['distanceName'] as String?),
              infoLine('Nội dung', r['content'] as String?),
              infoLine(
                'Ngày gửi',
                localTime(
                  DateTime.tryParse(r['createdAtUtc']?.toString() ?? ''),
                ),
              ),
              ...((r['evidenceLinks'] as List?) ?? []).map(
                (link) => TextButton.icon(
                  onPressed: () => openExternal(context, link as String),
                  icon: const Icon(Icons.attachment),
                  label: Text(
                    link.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          RunnerPanel(
            title: 'Phản hồi từ BTC',
            children: [
              Text(r['responseContent'] as String? ?? 'Chưa có phản hồi.'),
            ],
          ),
        ],
      ),
    ),
  );
}

class CreateComplaintScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final RunnerRepository repository;
  final Registration? initial;
  const CreateComplaintScreen({
    super.key,
    required this.api,
    required this.repository,
    this.initial,
  });
  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      content = TextEditingController(),
      evidence = TextEditingController();
  Registration? selected;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    content.dispose();
    evidence.dispose();
    super.dispose();
  }

  List<String> get links =>
      evidence.text.split(RegExp(r'\s+')).where((v) => v.isNotEmpty).toList();
  Future<List<Registration>> load() async {
    final rows = await widget.repository.registrations();
    selected =
        rows.where((r) => r.id == widget.initial?.id).firstOrNull ??
        rows.firstOrNull;
    return rows;
  }

  Future<void> attach() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (links.length >= 5) {
        throw Exception('Chỉ được đính kèm tối đa 5 bằng chứng.');
      }
      final url = await uploadEvidence(widget.repository);
      if (!mounted || url == null) return;
      evidence.text = [...links, url].join('\n');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> send() async {
    if (busy || selected == null || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.createComplaint(
        selected!,
        title.text,
        content.text,
        links,
      );
      if (mounted) {
        activityMessage(context, 'Đã gửi khiếu nại.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gửi khiếu nại')),
    body: ActivityResource<List<Registration>>(
      load: load,
      builder: (rows, reload) {
        if (rows.isEmpty) {
          return const Center(child: RunnerNotice('Bạn chưa có đăng ký giải.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: form,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Giải / cự ly',
                      border: OutlineInputBorder(),
                    ),
                    items: rows
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              '${r.eventName} · ${r.distanceLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(
                            () => selected = rows.firstWhere((r) => r.id == v),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: title,
                    enabled: !busy,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Vui lòng nhập tiêu đề.' : null,
                  ),
                  TextFormField(
                    controller: content,
                    enabled: !busy,
                    maxLength: 2000,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Nội dung'),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Vui lòng nhập nội dung.' : null,
                  ),
                  TextFormField(
                    controller: evidence,
                    enabled: !busy,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Bằng chứng (1–5 liên kết)',
                      helperText: 'Mỗi liên kết HTTP/HTTPS trên một dòng.',
                    ),
                    validator: (_) {
                      if (links.isEmpty || links.length > 5) {
                        return 'Cần từ 1 đến 5 bằng chứng.';
                      }
                      return links.any((l) {
                            final u = Uri.tryParse(l);
                            return u == null ||
                                !['http', 'https'].contains(u.scheme) ||
                                u.host.isEmpty;
                          })
                          ? 'Liên kết phải là HTTP/HTTPS hợp lệ.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : send,
              child: Text(busy ? 'Đang xử lý…' : 'Gửi khiếu nại'),
            ),
          ],
        );
      },
    ),
  );
}
