import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:runner_mobile/features/runner/domain/runner_models.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_detail_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_list_screen.dart';
import 'package:runner_mobile/features/runner/presentation/widgets/runner_widgets.dart';

import 'support/fake_runner_repository.dart';

const _user = UserEntity(username: 'runner', role: 'Runner', token: 'test');

class _Repository extends FakeRunnerRepository {
  _Repository() {
    status = 'confirmed';
  }
  bool offline = false;
  String? checkedAt;
  int requests = 0;

  @override
  Registration get reg =>
      Registration({...super.reg.data, 'checkedInAtUtc': checkedAt});

  @override
  Future<Registration> registration(String id) async {
    requests++;
    if (offline) throw Exception('Offline');
    return reg;
  }

  @override
  Future<List<Registration>> registrations() async {
    if (offline) throw Exception('Offline');
    return [reg];
  }
}

Future<void> _open(WidgetTester tester, _Repository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RegistrationDetailScreen(
        registrationId: 'r1',
        user: _user,
        repository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'confirmed ticket updates check-in and stops polling after success',
    (tester) async {
      final repo = _Repository();
      await _open(tester, repo);
      expect(find.text('Chưa check-in'), findsOneWidget);
      repo.checkedAt = '2026-10-22T08:00:00Z';
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Đã check-in'), findsOneWidget);
      expect(
        find.text(localTime(DateTime.parse(repo.checkedAt!))),
        findsOneWidget,
      );
      final requests = repo.requests;
      await tester.pump(const Duration(seconds: 9));
      expect(repo.requests, requests);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed polling and manual refresh preserve ticket; recovery clears warning',
    (tester) async {
      final repo = _Repository();
      await _open(tester, repo);
      repo.offline = true;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        find.textContaining('Chưa cập nhật được trạng thái'),
        findsOneWidget,
      );
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(QrImageView),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('1001'), findsOneWidget);
      repo.offline = false;
      repo.checkedAt = '2026-10-22T08:00:00Z';
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byType(CheckInStatus),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đã check-in'), findsOneWidget);
      expect(
        find.textContaining('Chưa cập nhật được trạng thái'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pauses requests in background and refreshes immediately on resume',
    (tester) async {
      final repo = _Repository();
      await _open(tester, repo);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      final requests = repo.requests;
      repo.checkedAt = '2026-10-22T08:00:00Z';
      await tester.pump(const Duration(seconds: 6));
      expect(repo.requests, requests);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(find.text('Đã check-in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('list retains checked-in ticket on refresh failure', (
    tester,
  ) async {
    final repo = _Repository()..checkedAt = '2026-10-22T08:00:00Z';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationListScreen(user: _user, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã check-in'), findsOneWidget);
    repo.offline = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Chưa cập nhật được danh sách vé'),
      findsOneWidget,
    );
    expect(find.text('Đã check-in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
