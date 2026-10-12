import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/presentation/controller/auth_controller.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../domain/entities/event_entity.dart';
import '../controller/home_controller.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/filter_card.dart';
import '../widgets/event_card.dart';
import '../widgets/event_detail_modal.dart';

class HomeScreen extends StatefulWidget {
  final UserEntity user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeController = HomeController();
  final _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _homeController.addListener(_onControllerUpdate);
    _homeController.fetchEvents();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _homeController.removeListener(_onControllerUpdate);
    _homeController.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authController.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showEventDetail(EventEntity event) {
    EventDetailModal.show(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandLogo(iconSize: 18, fontSize: 17),
        actions: [
          // Runner user badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.user.fullName ?? widget.user.username,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _homeController.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _homeController.fetchEvents(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP BANNER CAROUSEL (Image 2 Top)
                    BannerCarousel(
                      bannerEvents: _homeController.bannerEvents,
                      onEventTap: _showEventDetail,
                    ),

                    const SizedBox(height: 14),

                    // 2. FILTER BOX (Image 2 Middle)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: FilterCard(controller: _homeController),
                    ),

                    const SizedBox(height: 16),

                    // 3. SPORTS SECTION HEADER & EVENT LIST (Image 2 Bottom)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildSportsSection(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSportsSection() {
    final filtered = _homeController.filteredEvents;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title: "🏃 THỂ THAO"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_run_rounded,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'THỂ THAO',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} giải chạy',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Event List
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    const Text(
                      'Không tìm thấy giải chạy phù hợp',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _homeController.resetFilters(),
                      child: const Text('Đặt lại bộ lọc',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final ev = filtered[index];
                return EventCard(
                  event: ev,
                  onTap: () => _showEventDetail(ev),
                );
              },
            ),
        ],
      ),
    );
  }
}
