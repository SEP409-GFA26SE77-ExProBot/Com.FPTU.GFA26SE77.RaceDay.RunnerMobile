import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/presentation/controller/auth_controller.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../../runner/data/runner_repository_impl.dart';
import '../../../runner/domain/runner_repository.dart';
import '../../../runner/presentation/screens/event_detail_screen.dart';
import '../../../runner/presentation/screens/registration_list_screen.dart';
import '../../../runner/presentation/widgets/runner_widgets.dart';
import '../controller/home_controller.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/filter_card.dart';
import '../widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  final UserEntity user;
  const HomeScreen({super.key, required this.user});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final controller = HomeController();
  late final RunnerRepository repository;
  int tab = 0;
  @override
  void initState() {
    super.initState();
    repository = RunnerRepositoryImpl(token: widget.user.token);
    controller.addListener(_changed);
    controller.fetchEvents();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Các đăng ký của bạn được lưu trên hệ thống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final auth = AuthController();
    await auth.logout();
    auth.dispose();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  void _open(String id) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: id,
        user: widget.user,
        repository: repository,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceMuted,
    appBar: AppBar(
      title: const BrandLogo(iconSize: 18, fontSize: 20),
      actions: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(
            widget.user.fullName ?? widget.user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: _logout,
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Khám phá',
        ),
        NavigationDestination(
          icon: Icon(Icons.confirmation_number_outlined),
          selectedIcon: Icon(Icons.confirmation_number),
          label: 'Đăng ký của tôi',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: tab == 1
            ? RegistrationListScreen(user: widget.user, repository: repository)
            : controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null
            ? Center(
                child: RunnerNotice(
                  controller.error!,
                  onRetry: controller.fetchEvents,
                ),
              )
            : RefreshIndicator(
                onRefresh: controller.fetchEvents,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  children: [
                    BannerCarousel(
                      bannerEvents: controller.bannerEvents,
                      onEventTap: (e) => _open(e.id),
                    ),
                    const SizedBox(height: 12),
                    FilterCard(controller: controller),
                    const SizedBox(height: 16),
                    Text(
                      'Hiển thị ${controller.filteredEvents.length}/${controller.allEvents.length} giải chạy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (controller.filteredEvents.isEmpty)
                      RunnerNotice(
                        controller.allEvents.isEmpty
                            ? 'Hiện chưa có giải chạy được công bố.'
                            : 'Không tìm thấy giải phù hợp.',
                        onRetry: controller.resetFilters,
                      ),
                    ...controller.filteredEvents.map(
                      (e) => EventCard(event: e, onTap: () => _open(e.id)),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
