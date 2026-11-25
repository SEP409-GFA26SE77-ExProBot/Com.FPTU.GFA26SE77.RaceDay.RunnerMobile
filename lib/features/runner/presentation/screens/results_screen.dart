import 'package:flutter/material.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';

Widget resultCard(Json row) => RunnerPanel(
  title: '${row['eventName']} · ${row['distanceName']}',
  children: [
    Text('${row['fullName']} · BIB ${row['bib'] ?? '—'}'),
    infoLine('Xếp hạng', row['rank']?.toString()),
    infoLine('Thời gian hoàn thành', row['totalTime'] as String?),
    infoLine('Pace (phút/km)', row['pace'] as String?),
  ],
);

class MyResultsScreen extends StatelessWidget {
  final RunnerActivityApi api;
  const MyResultsScreen({super.key, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thành tích của tôi')),
    body: ActivityResource<List<Json>>(
      load: api.myResults,
      builder: (rows, reload) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Cập nhật kết quả'),
          ),
          if (rows.isEmpty)
            const RunnerNotice('Chưa có thành tích hoàn thành.'),
          ...rows.map(resultCard),
        ],
      ),
    ),
  );
}

class LeaderboardScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final String eventId, eventName;
  final String? initialDistance;
  const LeaderboardScreen({
    super.key,
    required this.api,
    required this.eventId,
    required this.eventName,
    this.initialDistance,
  });
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String? distanceId;
  String gender = 'All';
  int page = 1, revision = 0;
  Future<List<Json>> distances() async {
    final rows = await widget.api.distances(widget.eventId);
    distanceId =
        rows.where((r) => r['id'] == widget.initialDistance).firstOrNull?['id']
            as String? ??
        rows.firstOrNull?['id'] as String?;
    return rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bảng xếp hạng')),
    body: ActivityResource<List<Json>>(
      load: distances,
      builder: (rows, reloadDistances) {
        if (rows.isEmpty) {
          return const Center(child: RunnerNotice('Giải chưa có cự ly.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.eventName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: distanceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cự ly',
                      border: OutlineInputBorder(),
                    ),
                    items: rows
                        .map(
                          (r) => DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text('${r['type']} · ${r['distanceKm']} km'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      distanceId = v;
                      page = 1;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: {'All': 'Tất cả', 'Male': 'Nam', 'Female': 'Nữ'}
                        .entries
                        .map(
                          (e) => ChoiceChip(
                            label: Text(e.value),
                            selected: gender == e.key,
                            onSelected: (_) => setState(() {
                              gender = e.key;
                              page = 1;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ActivityResource<ActivityPage>(
                key: ValueKey('$distanceId:$gender:$page:$revision'),
                load: () => widget.api.leaderboard(
                  widget.eventId,
                  distanceId!,
                  gender,
                  page: page,
                ),
                builder: (data, reload) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextButton.icon(
                      onPressed: reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Cập nhật kết quả'),
                    ),
                    if (!data.published)
                      const RunnerNotice('BTC chưa công bố kết quả cự ly này.')
                    else if (data.items.isEmpty)
                      const RunnerNotice('Chưa có kết quả phù hợp.'),
                    ...data.items.map(resultCard),
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
