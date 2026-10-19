import 'dart:math';
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
import '../models/home_filter_selection.dart';
import '../widgets/event_card.dart';
import '../widgets/event_filter_sheet.dart';
import '../widgets/event_pagination_bar.dart';
import '../widgets/home_search_toolbar.dart';

class HomeScreen extends StatefulWidget {
  final UserEntity user;
  final HomeController? controller;
  final RunnerRepository? repository;
  const HomeScreen({
    super.key,
    required this.user,
    this.controller,
    this.repository,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeController controller;
  late final RunnerRepository repository;
  final ScrollController _scrollController = ScrollController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.controller ?? HomeController();
    repository =
        widget.repository ?? RunnerRepositoryImpl(token: widget.user.token);
    controller.addListener(_changed);
    controller.fetchEvents();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    _scrollController.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible =
        state == AppLifecycleState.resumed &&
        tab == 0 &&
        (ModalRoute.of(context)?.isCurrent ?? false);
    controller.setActive(visible);
    if (visible) controller.fetchEvents();
  }

  Future<void> _open(String id) async {
    controller.setActive(false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: id,
          user: widget.user,
          repository: repository,
        ),
      ),
    );
    if (!mounted) return;
    controller.setActive(tab == 0);
    await controller.fetchEvents();
  }

  Widget _buildFilterChipsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (controller.selectedDistance !=
                HomeFilterSelection.defaultDistance)
              _buildFilterChip(
                label: controller.selectedDistance,
                onDeleted: () =>
                    controller.clearFilter(HomeFilterField.distance),
              ),
            if (controller.selectedLocation !=
                HomeFilterSelection.defaultLocation)
              _buildFilterChip(
                label: controller.selectedLocation,
                onDeleted: () =>
                    controller.clearFilter(HomeFilterField.location),
              ),
            if (controller.selectedTime != HomeFilterSelection.defaultTime)
              _buildFilterChip(
                label: controller.selectedTime,
                onDeleted: () => controller.clearFilter(HomeFilterField.time),
              ),
            if (controller.selectedStatus != HomeFilterSelection.defaultStatus)
              _buildFilterChip(
                label: controller.selectedStatus,
                onDeleted: () => controller.clearFilter(HomeFilterField.status),
              ),
            TextButton(
              onPressed: controller.clearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDeleted,
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primary),
        labelStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = controller.totalFiltered;
    final summaryText = total == 0
        ? '0 giải phù hợp'
        : '${(controller.currentPage - 1) * HomeController.pageSize + 1}–${min(controller.currentPage * HomeController.pageSize, total)} / $total giải phù hợp';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Row(
        children: [
          Text(
            summaryText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (controller.isResolvingLifecycle &&
              controller.selectedStatus != HomeFilterSelection.defaultStatus)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 6),
                Text(
                  'Đang kiểm tra trạng thái…',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        onDestinationSelected: (i) {
          setState(() => tab = i);
          controller.setActive(i == 0);
          if (i == 0) controller.fetchEvents();
        },
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
              ? RegistrationListScreen(
                  user: widget.user,
                  repository: repository,
                )
              : controller.isInitialLoading
              ? const Center(child: CircularProgressIndicator())
              : controller.error != null && controller.allEvents.isEmpty
              ? Center(
                  child: RunnerNotice(
                    controller.error!,
                    onRetry: controller.fetchEvents,
                  ),
                )
              : Column(
                  children: [
                    // Refresh warning notice if refresh failed while retaining old data
                    if (controller.refreshError != null)
                      Container(
                        color: AppColors.errorBg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Không thể cập nhật danh sách',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: controller.fetchEvents,
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),

                    // 1. Search Toolbar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                      child: HomeSearchToolbar(
                        initialQuery: controller.searchQuery,
                        onSearchChanged: controller.setSearchQuery,
                        onSearchCleared: () => controller.setSearchQuery(''),
                        activeFilterCount: controller.activeFilterCount,
                        onOpenFilter: () =>
                            EventFilterSheet.show(context, controller),
                      ),
                    ),

                    // 2. Applied Filter Chips
                    if (controller.hasActiveFilters) _buildFilterChipsBar(),

                    // 3. Result Summary Row
                    _buildSummaryRow(),

                    // 4. Expanded Scrollable Event List with RefreshIndicator
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: controller.fetchEvents,
                        child: controller.filteredEvents.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 60),
                                    child: RunnerNotice(
                                      controller.allEvents.isEmpty
                                          ? 'Hiện chưa có giải chạy được công bố.'
                                          : 'Không tìm thấy giải phù hợp.',
                                      onRetry: controller.allEvents.isEmpty
                                          ? controller.fetchEvents
                                          : controller.resetFilters,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                                itemCount: controller.pagedEvents.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final ev = controller.pagedEvents[i];
                                  return EventCard(
                                    key: ValueKey(ev.id),
                                    event: ev,
                                    statusLabel: controller.statusFor(ev),
                                    onTap: () => _open(ev.id),
                                  );
                                },
                              ),
                      ),
                    ),

                    // 5. Fixed Pagination Bar
                    if (controller.pageCount > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                        child: EventPaginationBar(
                          currentPage: controller.currentPage,
                          pageCount: controller.pageCount,
                          onPageChanged: (page) {
                            controller.setPage(page);
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
