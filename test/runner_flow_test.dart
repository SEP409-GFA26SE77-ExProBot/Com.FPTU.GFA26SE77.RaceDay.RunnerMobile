import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:runner_mobile/core/network/api_client.dart';
import 'package:runner_mobile/core/errors/app_exceptions.dart';
import 'package:runner_mobile/features/home/data/datasources/event_remote_data_source.dart';
import 'package:runner_mobile/features/home/data/models/event_model.dart';
import 'package:runner_mobile/features/home/domain/entities/event_entity.dart';
import 'package:runner_mobile/features/home/domain/repositories/event_repository.dart';
import 'package:runner_mobile/features/home/domain/usecases/get_events_usecase.dart';
import 'package:runner_mobile/features/home/presentation/controller/home_controller.dart';
import 'package:runner_mobile/features/home/presentation/widgets/filter_card.dart';
import 'package:runner_mobile/features/runner/domain/registration_validation.dart';
import 'package:runner_mobile/features/runner/presentation/controllers/payment_controller.dart';
import 'package:runner_mobile/features/runner/presentation/screens/payment_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_detail_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_form_screen.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:runner_mobile/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:runner_mobile/features/runner/presentation/screens/event_detail_screen.dart';
import 'support/fake_runner_repository.dart';

const user = UserEntity(
  id: 'u1',
  username: 'runner',
  role: 'Runner',
  token: 'test',
);

class EventsFake implements EventRepository {
  final List<EventEntity> values;
  EventsFake(this.values);
  @override
  Future<List<EventEntity>> getEvents() async => values;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.onSessionExpired = null;
  });
  test(
    'list contract parses chips and numeric km without fabricated distances',
    () {
      final e = EventModel.fromJson({
        'id': '1',
        'name': 'Race',
        'location': 'Hà Nội',
        'date': '2026-11-01',
        'status': 'approved',
        'distanceTypes': ['Half marathon'],
        'distanceKms': [21.1],
      });
      expect(e.distanceTypes, ['Half marathon']);
      expect(e.distanceKms, [21.1]);
      expect(e.distances, isEmpty);
    },
  );
  test('empty and failed API do not return seed races', () async {
    final empty = EventRemoteDataSourceImpl(
      client: ApiClient(
        client: MockClient((_) async => http.Response('[]', 200)),
      ),
    );
    expect(await empty.getEvents(), isEmpty);
    final failed = EventRemoteDataSourceImpl(
      client: ApiClient(
        client: MockClient(
          (_) async => http.Response('{"error":"Unavailable"}', 500),
        ),
      ),
    );
    await expectLater(failed.getEvents(), throwsA(isA<AppException>()));
  });
  test('filters apply real date, km and reset', () async {
    final c = HomeController(
      clock: () => DateTime(2026, 10, 14),
      getEventsUseCase: GetEventsUseCase(
        EventsFake([
          EventModel.fromJson({
            'id': '1',
            'name': 'Half',
            'location': 'Hà Nội',
            'date': '2026-10-20',
            'status': 'registration-open',
            'distanceKms': [21.1],
          }),
          EventModel.fromJson({
            'id': '2',
            'name': 'Full',
            'location': 'Đà Nẵng',
            'date': '2026-11-20',
            'status': 'approved',
            'distanceKms': [42.195],
          }),
          EventModel.fromJson({
            'id': '3',
            'name': 'Old',
            'location': 'Huế',
            'date': '2026-09-01',
            'status': 'completed',
            'distanceKms': [5],
          }),
        ]),
      ),
    );
    await c.fetchEvents();
    expect(c.selectedTime, 'Tất cả thời gian');
    expect(c.filteredEvents.length, 3);
    c.setTime('Sắp diễn ra');
    expect(c.filteredEvents.length, 2);
    c.setTime('Tháng này');
    expect(c.filteredEvents.single.id, '1');
    c.setTime('Tất cả thời gian');
    c.setDistance('42km');
    expect(c.filteredEvents.single.id, '2');
    c.resetFilters();
    expect(c.selectedTime, 'Tất cả thời gian');
    expect(c.filteredEvents.length, 3);
    c.dispose();
  });
  test(
    'validation accepts optional fields and rejects invalid phone/id/age',
    () {
      expect(validateRegistrationField('emergencyPhone', ''), isNull);
      expect(validateRegistrationField('phone', '090 123 4567'), isNull);
      expect(validateRegistrationField('phone', '12345'), isNotNull);
      expect(validateRegistrationField('idNumber', '012345678901'), isNull);
      expect(validateRegistrationField('idNumber', '123'), isNotNull);
      expect(
        validateRegistrationField(
          'dateOfBirth',
          '2026-02-30',
          today: DateTime(2026, 10, 14),
        ),
        isNotNull,
      );
      expect(
        validateRegistrationField(
          'dateOfBirth',
          '2000-10-14',
          today: DateTime(2026, 10, 14),
        ),
        isNull,
      );
      expect(validateRegistrationField('heightCm', '99'), isNotNull);
      expect(validateRegistrationField('bloodType', 'AB+'), isNull);
    },
  );
  test('protected 401 expires session; login 401 does not', () async {
    var calls = 0;
    ApiClient.onSessionExpired = () => calls++;
    final api = ApiClient(
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      api.get('https://example.com', token: 'token'),
      throwsA(isA<AuthException>()),
    );
    expect(calls, 1);
    await expectLater(
      api.post('https://example.com/login'),
      throwsA(isA<AppException>()),
    );
    expect(calls, 1);
  });
  test('multipart carries auth and file bytes; PUT sends JSON', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        if (request.method == 'POST') {
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          expect(request.body, contains('certificate.pdf'));
        } else {
          expect(jsonDecode(request.body), {'fullName': 'Runner'});
        }
        return http.Response('{"fileUrl":"https://example.com/file"}', 200);
      }),
    );
    await api.upload(
      'https://example.com/upload',
      token: 'token',
      filename: 'certificate.pdf',
      bytes: const Base64Decoder().convert('YWJj'),
    );
    await api.put(
      'https://example.com/resubmit',
      token: 'token',
      body: {'fullName': 'Runner'},
    );
  });
  test('mock button is serialized and payment stops at approval', () async {
    final repo = FakeRunnerRepository();
    final c = PaymentController(
      repository: repo,
      registrationId: 'r1',
      userId: 'u1',
    );
    await c.refresh(prepareCheckout: true);
    expect(c.canPay, isTrue);
    expect(c.isMock, isTrue);
    final gate = Completer<void>();
    repo.payGate = gate.future;
    final first = c.testPayment();
    await c.testPayment();
    await Future<void>.delayed(Duration.zero);
    expect(repo.mockCalls, 1);
    gate.complete();
    await first;
    expect(c.registration!.status, 'pending_approval');
    expect(c.canPay, isFalse);
    expect(c.registration!.hasTicket, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('runner_payment_u1_r1'),
      'p1',
    );
    c.dispose();
  });
  test('live and unknown mode cannot invoke mock pay', () async {
    for (final mode in ['live', 'unknown']) {
      final repo = FakeRunnerRepository()
        ..mode = mode
        ..failMode = (mode == 'unknown');
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh();
      await c.testPayment();
      expect(repo.mockCalls, 0);
      expect(c.isMock, isFalse);
      c.dispose();
    }
  });
  test('timeout after paid recovers; no second checkout or cancel', () async {
    final repo = FakeRunnerRepository()..timeoutAfterPay = true;
    final c = PaymentController(
      repository: repo,
      registrationId: 'r1',
      userId: 'u1',
    );
    await c.refresh();
    await c.testPayment();
    expect(c.payment!.paid, isTrue);
    expect(c.registration!.status, 'pending_approval');
    await c.refresh(prepareCheckout: true);
    expect(repo.checkoutCalls, 0);
    await c.cancel();
    expect(repo.cancelCalls, 0);
    c.dispose();
  });
  test(
    'paid with pending registration stays unresolved with the existing API',
    () async {
      final repo = FakeRunnerRepository()
        ..paymentStatus = 'paid'
        ..failSync = true;
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u2',
      );
      await c.refresh(prepareCheckout: true);
      expect(c.needsReconciliation, isTrue);
      expect(c.canPay, isFalse);
      expect(repo.checkoutCalls, 0);
      await c.refresh();
      expect(c.registration!.status, 'pending_payment');
      expect(c.needsReconciliation, isTrue);
      await c.cancel();
      expect(repo.cancelCalls, 0);
      c.dispose();
    },
  );
  test(
    'unknown gateway state blocks cancel and checkout until a successful sync',
    () async {
      final repo = FakeRunnerRepository()..failSync = true;
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh(prepareCheckout: true);
      expect(c.verified, isFalse);
      expect(c.canPay, isFalse);
      expect(await c.cancel(), isFalse);
      expect(repo.cancelCalls, 0);
      expect(repo.checkoutCalls, 0);
      repo.failSync = false;
      await c.refresh();
      expect(c.canPay, isTrue);
      c.dispose();
    },
  );
  test('malformed login never creates an offline runner session', () async {
    final auth = AuthRemoteDataSourceImpl(
      client: ApiClient(
        client: MockClient(
          (_) async => http.Response('{"accessToken":"invalid.jwt"}', 200),
        ),
      ),
    );
    await expectLater(auth.login('an.nguyen', 'MatKhau@123'), throwsException);
  });
  testWidgets('event detail fits a narrow phone and offers registration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRunnerRepository()..hasRegistration = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(eventId: 'e1', user: user, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đăng ký cự ly đã chọn'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('test button only displayed in mock payment screen', (
    tester,
  ) async {
    final repo = FakeRunnerRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(repository: repo, registrationId: 'r1', user: user),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('mock-pay')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mock-pay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mock-pay')), findsNothing);
    expect(
      find.textContaining('Đã thanh toán — chờ BTC duyệt'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('ticket QR and BIB appear only after confirmation', (
    tester,
  ) async {
    final repo = FakeRunnerRepository()
      ..status = 'confirmed'
      ..paymentStatus = 'paid';
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationDetailScreen(
          registrationId: 'r1',
          user: user,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    repo.status = 'pending_approval';
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationDetailScreen(
          registrationId: 'r1',
          user: user,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets('form prefill, steps preserve values and accepted submission', (
    tester,
  ) async {
    final repo = FakeRunnerRepository()..hasRegistration = false;
    repo.profileData.addAll({
      'dateOfBirth': '2000-01-01',
      'idNumber': '012345678901',
      'bloodType': 'O+',
      'medicalCodes': ['none'],
      'emergencyName': 'Nguyen Van B',
      'emergencyPhone': '0912345678',
      'emergencyRelation': 'Ba/Mẹ',
    });
    final race = await repo.event('e1');
    await tester.pumpWidget(
      MaterialApp(
        home: RegistrationFormScreen(
          race: race,
          distance: race.distances.single,
          user: user,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('distance-d1')), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      final next = find.widgetWithText(FilledButton, 'Tiếp tục');
      await tester.scrollUntilVisible(
        next,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('liability')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('liability')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liability')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('payment-terms')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('payment-terms')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payment-terms')));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Thanh toán');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.createdBody?['fullName'], 'Runner Test');
    expect(repo.createdBody?['liabilityAccepted'], true);
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets('reset clears search text and keeps dropdown values valid', (
    tester,
  ) async {
    final c = HomeController(
      getEventsUseCase: GetEventsUseCase(EventsFake([])),
    );
    await c.fetchEvents();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, _) => FilterCard(controller: c),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'search');
    await tester.pump();
    c.resetFilters();
    await tester.pump();
    expect(find.text('search'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
