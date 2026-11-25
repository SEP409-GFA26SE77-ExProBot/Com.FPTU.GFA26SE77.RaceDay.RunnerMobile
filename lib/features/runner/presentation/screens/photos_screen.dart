import 'package:flutter/material.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';

class PhotosScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final RunnerRepository repository;
  final Registration? initial;
  const PhotosScreen({
    super.key,
    required this.api,
    required this.repository,
    this.initial,
  });
  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final bib = TextEditingController();
  List<Registration> registrations = [];
  String? selectedEvent, searchedEvent, searchedBib;
  int page = 1, revision = 0;
  @override
  void dispose() {
    bib.dispose();
    super.dispose();
  }

  Future<List<Registration>> load() async {
    final rows = await widget.repository.registrations();
    registrations = rows.where((r) => r.bib?.isNotEmpty ?? false).toList();
    final initial =
        registrations.where((r) => r.id == widget.initial?.id).firstOrNull ??
        registrations.firstOrNull;
    selectedEvent = initial?.eventId;
    bib.text = initial?.bib ?? '';
    searchedEvent = selectedEvent;
    searchedBib = bib.text;
    return registrations;
  }

  void search() {
    if (selectedEvent == null || bib.text.trim().isEmpty) return;
    setState(() {
      searchedEvent = selectedEvent;
      searchedBib = bib.text.trim();
      page = 1;
      revision++;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ảnh sự kiện'),
      actions: [
        IconButton(
          tooltip: 'Khiếu nại ảnh của tôi',
          icon: const Icon(Icons.report_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoDisputesScreen(api: widget.api),
            ),
          ),
        ),
      ],
    ),
    body: ActivityResource<List<Registration>>(
      load: load,
      builder: (rows, reload) {
        if (rows.isEmpty) {
          return const Center(
            child: RunnerNotice(
              'Bạn chưa có BIB. Ảnh sẽ được tìm theo BIB sau khi đăng ký được xác nhận.',
            ),
          );
        }
        final events = {for (final r in rows) r.eventId: r.eventName};
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedEvent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Giải chạy',
                      border: OutlineInputBorder(),
                    ),
                    items: events.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      selectedEvent = v;
                      bib.text =
                          rows.firstWhere((r) => r.eventId == v).bib ?? '';
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bib,
                          decoration: const InputDecoration(
                            labelText: 'Số BIB',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => search(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: search,
                        child: const Text('Tìm ảnh'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ActivityResource<ActivityPage>(
                key: ValueKey('$searchedEvent:$searchedBib:$page:$revision'),
                load: () =>
                    widget.api.photos(searchedEvent!, searchedBib!, page: page),
                builder: (data, reloadPhotos) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text(
                      '${data.total} ảnh · BIB $searchedBib',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: reloadPhotos,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại ảnh'),
                    ),
                    if (data.items.isEmpty)
                      const RunnerNotice(
                        'Chưa có ảnh cho BIB này. Ảnh đang xử lý hoặc chưa được xuất bản sẽ xuất hiện sau.',
                      ),
                    ...data.items.map(
                      (photo) => Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PhotoDetailScreen(
                                  api: widget.api,
                                  photoId: photo['id'] as String,
                                ),
                              ),
                            );
                            if (mounted) setState(() => revision++);
                          },
                          child: Column(
                            children: [
                              SizedBox(
                                height: 220,
                                width: double.infinity,
                                child: ActivityImage(
                                  photo['url'] as String?,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              ListTile(
                                title: Text(
                                  'BIB ${jsonRows(photo['tags']).map((t) => t['bib']).join(', ')}',
                                ),
                                subtitle: Text(
                                  photo['zone']?.toString() ?? 'Ảnh sự kiện',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ActivityPager(
                      data: data,
                      onPage: (v) => setState(() => page = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PhotoDetailScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final String photoId;
  const PhotoDetailScreen({
    super.key,
    required this.api,
    required this.photoId,
  });
  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool busy = false;
  Future<void> download() async {
    setState(() => busy = true);
    try {
      final bytes = await widget.api.downloadPhoto(widget.photoId);
      if (mounted) await saveImage(context, bytes, 'raceday-${widget.photoId}');
    } catch (e) {
      if (mounted) activityMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> report() async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActivityReasonDialog(
        title: 'Báo ảnh sai BIB',
        submit: (reason) => widget.api.reportPhoto(widget.photoId, reason),
      ),
    );
    if (sent == true && mounted) {
      activityMessage(context, 'Đã gửi báo cáo. Photographer sẽ kiểm tra lại.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết ảnh')),
    body: ActivityResource<Json>(
      load: () => widget.api.photo(widget.photoId),
      builder: (photo, reload) => Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: ActivityImage(photo['url'] as String?)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'BIB ${jsonRows(photo['tags']).map((t) => t['bib']).join(', ')}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: busy ? null : download,
                      icon: const Icon(Icons.download),
                      label: Text(busy ? 'Đang xử lý…' : 'Lưu ảnh'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : report,
                      icon: const Icon(Icons.report_outlined),
                      label: const Text('Báo sai'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class PhotoDisputesScreen extends StatelessWidget {
  final RunnerActivityApi api;
  const PhotoDisputesScreen({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khiếu nại ảnh của tôi')),
    body: ActivityResource<List<Json>>(
      load: api.photoDisputes,
      builder: (rows, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại'),
          ),
          if (rows.isEmpty) const RunnerNotice('Bạn chưa gửi khiếu nại ảnh.'),
          ...rows.map(
            (r) => RunnerPanel(
              title: switch (r['status']) {
                'approved' => 'Đã chấp nhận',
                'rejected' => 'Đã từ chối',
                _ => 'Chờ xử lý',
              },
              children: [
                Text(r['reason'] as String),
                infoLine('Phản hồi', r['reviewNote'] as String?),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoDetailScreen(
                        api: api,
                        photoId: r['photoId'] as String,
                      ),
                    ),
                  ),
                  child: const Text('Xem ảnh'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
