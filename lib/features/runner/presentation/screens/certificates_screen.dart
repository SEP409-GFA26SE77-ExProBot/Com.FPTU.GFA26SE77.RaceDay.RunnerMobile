import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/activity_widgets.dart';
import '../widgets/runner_widgets.dart';

class CertificatesScreen extends StatelessWidget {
  final RunnerActivityApi api;
  final RunnerRepository repository;
  const CertificatesScreen({
    super.key,
    required this.api,
    required this.repository,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chứng nhận của tôi')),
    body: ActivityResource<List<Registration>>(
      load: repository.registrations,
      builder: (rows, reload) {
        final eligible = rows.where((r) => r.finished).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
            if (eligible.isEmpty)
              const RunnerNotice(
                'Chứng nhận xuất hiện khi bạn hoàn thành giải và có kết quả hợp lệ.',
              ),
            ...eligible.map(
              (r) => Card(
                child: ListTile(
                  title: Text(r.eventName),
                  subtitle: Text('${r.distanceLabel} · BIB ${r.bib ?? '—'}'),
                  trailing: const Icon(Icons.workspace_premium),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CertificateScreen(api: api, registrationId: r.id),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class CertificateScreen extends StatefulWidget {
  final RunnerActivityApi api;
  final String registrationId;
  const CertificateScreen({
    super.key,
    required this.api,
    required this.registrationId,
  });
  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final artwork = GlobalKey();
  bool busy = false;
  Future<void> download() async {
    setState(() => busy = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          artwork.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (mounted && bytes != null) {
        await saveImage(
          context,
          bytes.buffer.asUint8List(),
          'raceday-certificate-${widget.registrationId}',
        );
      }
    } catch (e) {
      if (mounted) {
        activityMessage(
          context,
          'Không xuất được chứng nhận. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chứng nhận hoàn thành')),
    body: ActivityResource<Json?>(
      load: () => widget.api.certificate(widget.registrationId),
      builder: (data, reload) {
        if (data == null) {
          return Center(
            child: RunnerNotice(
              'Đăng ký chưa đủ điều kiện nhận chứng nhận.',
              onRetry: reload,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: RepaintBoundary(
                  key: artwork,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff8ef),
                      border: Border.all(color: Colors.deepOrange, width: 3),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.flag,
                          color: Colors.deepOrange,
                          size: 42,
                        ),
                        const Text(
                          'RACEDAY',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'CHỨNG NHẬN HOÀN THÀNH',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Trao cho vận động viên'),
                        const SizedBox(height: 8),
                        Text(
                          data['runnerName'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data['eventName'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${data['distance']} · ${calendarDate(data['raceDate'] as String?)}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text('BIB ${data['bib'] ?? '—'}'),
                        Text(
                          'Thời gian: ${data['finishTime']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Pace: ${data['pace']} phút/km'),
                        const SizedBox(height: 24),
                        const Text(
                          'Ghi nhận nỗ lực trên từng bước chạy.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : download,
              icon: const Icon(Icons.download),
              label: Text(busy ? 'Đang xuất ảnh…' : 'Lưu chứng nhận PNG'),
            ),
          ],
        );
      },
    ),
  );
}
