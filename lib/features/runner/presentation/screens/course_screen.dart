import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';

class CourseScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final String eventId, distanceId, title;
  const CourseScreen({
    super.key,
    required this.api,
    required this.eventId,
    required this.distanceId,
    required this.title,
  });
  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  final controller = MapController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ đường chạy')),
    body: ActivityResource<Json>(
      load: () => widget.api.course(widget.eventId, widget.distanceId),
      builder: (data, reload) {
        final points = jsonRows(data['polyline'])
            .map(
              (p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
            )
            .toList();
        final checkpoints = jsonRows(data['checkpoints']);
        if (points.length < 2) {
          return Center(
            child: RunnerNotice(
              'BTC chưa thiết lập tuyến chạy cho cự ly này.',
              onRetry: reload,
            ),
          );
        }
        final fit = CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
          maxZoom: 16,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} · ${data['distanceKm']} km',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.fitCamera(fit),
                    tooltip: 'Xem toàn tuyến',
                    icon: const Icon(Icons.center_focus_strong),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCameraFit: fit,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'vn.raceday.runner',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: Colors.deepOrange,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: checkpoints
                        .map(
                          (cp) => Marker(
                            point: LatLng(
                              (cp['lat'] as num).toDouble(),
                              (cp['lng'] as num).toDouble(),
                            ),
                            width: 48,
                            height: 48,
                            child: Tooltip(
                              message: '${cp['name']} · km ${cp['km']}',
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                icon: Icon(
                                  switch (cp['type']) {
                                    'start' => Icons.play_arrow,
                                    'finish' => Icons.flag,
                                    'aid' => Icons.water_drop,
                                    _ => Icons.location_on,
                                  },
                                  color: switch (cp['type']) {
                                    'start' => Colors.green,
                                    'finish' => Colors.red,
                                    'aid' => Colors.blue,
                                    _ => Colors.deepOrange,
                                  },
                                ),
                                onPressed: () => activityMessage(
                                  context,
                                  '${cp['name']} · km ${cp['km']}${cp['cutoff'] == null ? '' : ' · Cutoff ${cp['cutoff']}'}',
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => openExternal(
                          context,
                          'https://www.openstreetmap.org/copyright',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                children: checkpoints
                    .map(
                      (cp) => ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(cp['name'] as String),
                        subtitle: Text(
                          'Km ${cp['km']}${cp['cutoff'] == null ? '' : ' · Cutoff ${cp['cutoff']}'}',
                        ),
                        onTap: () => controller.move(
                          LatLng(
                            (cp['lat'] as num).toDouble(),
                            (cp['lng'] as num).toDouble(),
                          ),
                          16,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    ),
  );
}
