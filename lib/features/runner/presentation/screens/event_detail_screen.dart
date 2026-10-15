import 'package:flutter/material.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/runner_widgets.dart';
import 'registration_form_screen.dart';
import 'registration_detail_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final UserEntity user;
  final RunnerRepository repository;
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.user,
    required this.repository,
  });
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  RaceDetail? race;
  Registration? existing;
  String? selectedId, error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final detail = await widget.repository.event(widget.eventId);
      final registrations = await widget.repository.registrations();
      if (!mounted) return;
      race = detail;
      existing = registrations
          .where((r) => r.eventId == widget.eventId && r.status != 'cancelled')
          .firstOrNull;
      selectedId =
          detail.distances
              .where((d) => d.id == selectedId && d.hasSlot)
              .firstOrNull
              ?.id ??
          detail.distances.where((d) => d.hasSlot).firstOrNull?.id;
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _action() async {
    final r = race!;
    if (existing != null && existing!.status != 'pending_payment') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationDetailScreen(
            registrationId: existing!.id,
            user: widget.user,
            repository: widget.repository,
          ),
        ),
      );
    } else {
      final distance = r.distances.where((d) => d.id == selectedId).firstOrNull;
      final created = await Navigator.push<Registration>(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationFormScreen(
            race: r,
            distance: distance,
            resumeRegistration: existing,
            user: widget.user,
            repository: widget.repository,
          ),
        ),
      );
      if (created != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationDetailScreen(
              registrationId: created.id,
              user: widget.user,
              repository: widget.repository,
            ),
          ),
        );
      }
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = race;
    final enabled =
        !loading &&
        error == null &&
        r != null &&
        (existing != null || (r.acceptsNow && selectedId != null));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giải')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: enabled ? _action : null,
            child: Text(
              existing != null
                  ? (existing!.status == 'confirmed'
                        ? 'Xem vé của tôi'
                        : 'Xem đăng ký của tôi')
                  : 'Đăng ký cự ly đã chọn',
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: RunnerNotice(error!, onRetry: _load))
          : r == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: RaceImage(r.banner),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        r.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: StatusPill(r.registrationMessage),
                      ),
                      const SizedBox(height: 16),
                      RunnerPanel(
                        title: 'Thông tin giải',
                        children: [
                          infoLine(
                            'Ngày tổ chức',
                            '${calendarDate(r.date)}${r.endDate == null ? '' : ' – ${calendarDate(r.endDate)}'}',
                          ),
                          infoLine('Giờ bắt đầu', shortTime(r.startTime)),
                          infoLine('Địa điểm', r.location),
                          if (r.opensAt != null)
                            infoLine('Mở đăng ký', localTime(r.opensAt)),
                          if (r.closesAt != null)
                            infoLine('Đóng đăng ký', localTime(r.closesAt)),
                          infoLine('Giới thiệu', r.description),
                        ],
                      ),
                      RunnerPanel(
                        title: 'Chọn cự ly',
                        children: [
                          if (r.distances.isEmpty)
                            const Text('Chưa có thông tin cự ly.'),
                          ...r.distances.map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: d.hasSlot && existing == null
                                    ? () => setState(() => selectedId = d.id)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedId == d.id
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Colors.grey.shade300,
                                      width: selectedId == d.id ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            selectedId == d.id
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${d.name} · ${d.km} km',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      infoLine(
                                        'Giá tham khảo',
                                        money(d.estimatedPrice, d.currency),
                                      ),
                                      if (d.phaseName != null)
                                        Text(d.phaseName!),
                                      Text(
                                        d.capacity <= 0
                                            ? 'Không giới hạn số suất'
                                            : d.hasSlot
                                            ? 'Còn ${d.capacity - d.registered} / ${d.capacity} suất'
                                            : 'Đã hết suất',
                                      ),
                                      if (d.startAt != null)
                                        infoLine(
                                          'Giờ chạy',
                                          '${shortTime(d.startAt)}${d.endAt == null ? '' : ' – ${shortTime(d.endAt)}'}',
                                        ),
                                      infoLine('Xuất phát', d.startLocation),
                                      infoLine('Về đích', d.finishLocation),
                                      if (d.elevation > 0)
                                        infoLine(
                                          'Tổng độ cao leo',
                                          '${d.elevation} m',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Text(
                            'Giá tham khảo theo đợt bán vé và ngày hiện tại. Giá chính thức do hệ thống chốt khi tạo đơn; số suất có thể thay đổi.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      RunnerPanel(
                        title: 'Ban tổ chức',
                        children: [
                          infoLine('Tên', r.organizerName),
                          if (r.organizerEmail.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => openExternal(
                                context,
                                'mailto:${r.organizerEmail}',
                              ),
                              icon: const Icon(Icons.email_outlined),
                              label: Text(r.organizerEmail),
                            ),
                          if (r.organizerPhone.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => openExternal(
                                context,
                                'tel:${r.organizerPhone}',
                              ),
                              icon: const Icon(Icons.phone_outlined),
                              label: Text(r.organizerPhone),
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
