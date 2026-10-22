import 'package:flutter/material.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../domain/runner_models.dart';
import '../../domain/runner_repository.dart';
import '../widgets/runner_widgets.dart';
import 'registration_detail_screen.dart';

class RegistrationListScreen extends StatefulWidget {
  final UserEntity user;
  final RunnerRepository repository;
  const RegistrationListScreen({
    super.key,
    required this.user,
    required this.repository,
  });
  @override
  State<RegistrationListScreen> createState() => _RegistrationListScreenState();
}

class _RegistrationListScreenState extends State<RegistrationListScreen>
    with WidgetsBindingObserver {
  List<Registration> registrations = [];
  String? error;
  String status = 'all';
  bool loading = true;
  bool _refreshing = false, _hasLoaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ModalRoute.of(context)?.isCurrent == true) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      loading = !_hasLoaded;
      error = null;
    });
    try {
      registrations = await widget.repository.registrations();
      _hasLoaded = true;
    } catch (e) {
      error = _hasLoaded
          ? 'Chưa cập nhật được danh sách vé. Đang hiển thị thông tin gần nhất; vui lòng kiểm tra kết nối và thử lại.'
          : e.toString();
    } finally {
      _refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(Registration r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationDetailScreen(
          registrationId: r.id,
          user: widget.user,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && !_hasLoaded) {
      return Center(child: RunnerNotice(error!, onRetry: _load));
    }
    final filtered = registrations
        .where((r) => status == 'all' || r.status == status)
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) RunnerNotice(error!, onRetry: _load),
          Text(
            'Đăng ký của tôi',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              border: OutlineInputBorder(),
            ),
            items:
                [
                      'all',
                      'pending_payment',
                      'pending_approval',
                      'confirmed',
                      'rejected',
                      'cancelled',
                    ]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s == 'all'
                              ? 'Tất cả đăng ký'
                              : registrationStatusLabel(s),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) => setState(() => status = v!),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const RunnerNotice(
              'Chưa có đăng ký phù hợp. Khám phá giải để bắt đầu hành trình của bạn.',
            ),
          ...filtered.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(r),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(r.statusLabel),
                      if (r.status == 'confirmed') ...[
                        const SizedBox(height: 8),
                        CheckInStatus(checkedInAt: r.checkedInAt),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        r.eventName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(r.distanceLabel),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: Text(money(r.price, r.currency))),
                          Text(
                            r.status == 'confirmed' ? 'Xem vé' : 'Xem chi tiết',
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
