import 'package:flutter/material.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../data/runner_activity_api.dart';
import '../../domain/runner_repository.dart';
import 'photos_screen.dart';
import 'results_screen.dart';
import 'certificates_screen.dart';
import 'complaints_screen.dart';
import 'payment_history_screen.dart';

class RunnerActivityScreen extends StatelessWidget {
  final UserEntity user;
  final RunnerRepository repository;
  final RunnerActivityApi? api;
  const RunnerActivityScreen({
    super.key,
    required this.user,
    required this.repository,
    this.api,
  });
  @override
  Widget build(BuildContext context) {
    final service = api ?? RunnerActivityApi(token: user.token);
    Widget tile(IconData icon, String title, String subtitle, Widget screen) =>
        Card(
          child: ListTile(
            leading: Icon(icon, color: Colors.deepOrange),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen),
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hoạt động của tôi',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        tile(
          Icons.photo_library_outlined,
          'Ảnh sự kiện',
          'Tìm theo BIB, tải ảnh và báo sai',
          PhotosScreen(api: service, repository: repository),
        ),
        tile(
          Icons.emoji_events_outlined,
          'Thành tích',
          'Kết quả và thứ hạng cá nhân',
          MyResultsScreen(api: service),
        ),
        tile(
          Icons.workspace_premium_outlined,
          'Chứng nhận',
          'Xem và lưu chứng nhận hoàn thành',
          CertificatesScreen(api: service, repository: repository),
        ),
        tile(
          Icons.receipt_long_outlined,
          'Thanh toán',
          'Lịch sử giao dịch và yêu cầu hoàn tiền',
          PaymentHistoryScreen(
            api: service,
            repository: repository,
            user: user,
          ),
        ),
        tile(
          Icons.support_agent,
          'Khiếu nại',
          'Gửi bằng chứng và theo dõi phản hồi',
          ComplaintsScreen(api: service, repository: repository),
        ),
      ],
    );
  }
}
