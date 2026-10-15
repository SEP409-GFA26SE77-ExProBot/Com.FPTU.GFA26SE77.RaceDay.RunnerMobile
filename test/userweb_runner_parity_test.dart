import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_mobile/features/runner/data/registration_draft_store.dart';
import 'package:runner_mobile/features/runner/data/runner_mappers.dart';
import 'package:runner_mobile/features/runner/domain/runner_models.dart';
import 'package:runner_mobile/features/runner/domain/registration_form_rules.dart';
import 'package:runner_mobile/features/runner/presentation/controllers/payment_controller.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_form_screen.dart';
import 'package:runner_mobile/features/runner/presentation/screens/registration_detail_screen.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'support/fake_runner_repository.dart';

const runner = UserEntity(
  id: 'u1',
  username: 'runner',
  role: 'Runner',
  token: 'test',
);
Json validForm() => {
  'distanceId': 'd1',
  'fullName': 'Runner Test',
  'email': 'runner@example.com',
  'phone': '0901234567',
  'dateOfBirth': '2000-01-01',
  'idNumber': '012345678901',
  'gender': 'Male',
  'bloodType': 'O+',
  'medicalCodes': ['none'],
  'emergencyName': 'Nguyen Van B',
  'emergencyPhone': '0912345678',
  'emergencyRelation': 'Ba/Mẹ',
  'liabilityAccepted': true,
  'paymentTermsAccepted': true,
};

class HistoryWithoutQr extends FakeRunnerRepository {
  @override
  Future<List<RunnerPayment>> payments() async => [withoutQr()];
  RunnerPayment withoutQr() => RunnerPayment(
    id: pay.id,
    registrationId: pay.registrationId,
    status: paymentStatus,
    amount: pay.amount,
    currency: pay.currency,
    createdAt: pay.createdAt,
    checkoutUrl: pay.checkoutUrl,
  );
  @override
  Future<RunnerPayment> sync(String paymentId) async => withoutQr();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openForm(
  WidgetTester tester,
  FakeRunnerRepository repo, {
  bool rejected = false,
}) async {
  final race = await repo.event('e1');
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final reg = await Navigator.push<Registration>(
                context,
                MaterialPageRoute(
                  builder: (_) => RegistrationFormScreen(
                    race: race,
                    user: runner,
                    repository: repo,
                    existing: rejected ? repo.reg : null,
                  ),
                ),
              );
              if (context.mounted && reg != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegistrationDetailScreen(
                      registrationId: reg.id,
                      user: runner,
                      repository: repo,
                    ),
                  ),
                );
              }
            },
            child: const Text('Start'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'four steps require the same personal, medical and payment inputs as UserWeb',
    () {
      final data = validForm();
      for (var step = 0; step < 4; step++) {
        expect(validateRunnerStep(step, data), isEmpty);
      }
      for (final key in ['gender', 'dateOfBirth', 'idNumber']) {
        expect(validateRunnerStep(1, {...data, key: ''}), contains(key));
      }
      expect(
        validateRunnerStep(2, {...data, 'emergencyPhone': '+84 901 234 567'}),
        contains('emergencyPhone'),
      );
      expect(
        validateRunnerStep(2, {...data, 'emergencyRelation': ''}),
        contains('emergencyRelation'),
      );
      expect(
        validateRunnerStep(2, {...data, 'bloodType': ''}),
        contains('bloodType'),
      );
      expect(
        validateRunnerStep(3, {...data, 'paymentTermsAccepted': false}),
        contains('paymentTermsAccepted'),
      );
    },
  );

  test(
    'medical none is exclusive; other conditions require a valid certificate',
    () {
      expect(toggleMedical(['none'], 'injury'), ['injury']);
      expect(toggleMedical(['injury', 'respiratory'], 'none'), ['none']);
      final data = {
        ...validForm(),
        'medicalCodes': ['injury'],
      };
      expect(validateRunnerStep(2, data), contains('healthCert'));
      expect(validateRunnerStep(2, data, hasCertificate: true), isEmpty);
      expect(validateHealthFile('cert.PDF', 5 * 1024 * 1024), isNull);
      expect(validateHealthFile('cert.pdf', 5 * 1024 * 1024 + 1), isNotNull);
      expect(validateHealthFile('cert.exe', 200), isNotNull);
      expect(validateHealthFile('cert.jpg', 0), isNotNull);
    },
  );

  test('drafts are isolated by account and event and can be cleared', () async {
    const draft = RegistrationDraftStore('u1', 'e1');
    await draft.save(validForm());
    expect((await draft.read())?['fullName'], 'Runner Test');
    expect(await const RegistrationDraftStore('u2', 'e1').read(), isNull);
    expect(await const RegistrationDraftStore('u1', 'e2').read(), isNull);
    await draft.clear();
    expect(await draft.read(), isNull);
  });

  test(
    'checkout QR and transfer information survive history and sync responses',
    () async {
      final repo = HistoryWithoutQr();
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh(prepareCheckout: true);
      expect(repo.checkoutCalls, 1);
      expect(c.payment?.qrCode, repo.pay.qrCode);
      await c.poll();
      await c.refresh(prepareCheckout: true);
      expect(repo.checkoutCalls, 1);
      expect(c.payment?.accountNumber, '123456789');
      final parsed = paymentFromJson({
        'id': 'p2',
        'status': 'pending',
        'amount': 100,
        'createdAtUtc': '2026-01-01T00:00:00Z',
        'qrCode': 'bank payload',
        'accountName': 'BTC',
        'accountNumber': '999',
        'bin': '970422',
        'transferDescription': 'RD 123',
      });
      expect(parsed.qrCode, 'bank payload');
      expect(parsed.transferDescription, 'RD 123');
      expect(parsed.withCheckoutData(c.payment).accountNumber, '999');
      c.dispose();
    },
  );

  test(
    'cancel closes the mock payment before cancelling registration',
    () async {
      final repo = FakeRunnerRepository();
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh();
      expect(await c.cancel(), isTrue);
      expect(repo.mockCancelCalls, 1);
      expect(repo.cancelCalls, 1);
      expect(repo.paymentStatus, 'cancelled');
      c.dispose();
    },
  );

  testWidgets('four steps, payment back keeps form, cancel resets it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRunnerRepository()..hasRegistration = false;
    await const RegistrationDraftStore('u1', 'e1').save(validForm());
    await openForm(tester, repo);
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, find.byKey(const Key('form-next')));
    }
    await tapVisible(tester, find.byKey(const Key('form-next')));
    expect(find.byKey(const Key('payment-qr')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Runner Test'), findsOneWidget);
    expect(find.byKey(const Key('resume-payment')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('resume-payment')));
    await tapVisible(tester, find.text('Hủy thanh toán'));
    await tapVisible(tester, find.text('Hủy đơn'));
    expect(repo.cancelCalls, 1);
    expect(repo.mockCancelCalls, 1);
    expect(find.byKey(const Key('distance-d1')), findsOneWidget);
    expect(find.byKey(const Key('resume-payment')), findsNothing);
    expect(await const RegistrationDraftStore('u1', 'e1').read(), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'mock success returns approval screen; approval polling reveals BIB',
    (tester) async {
      final repo = FakeRunnerRepository()..hasRegistration = false;
      await const RegistrationDraftStore('u1', 'e1').save(validForm());
      await openForm(tester, repo);
      for (var i = 0; i < 4; i++) {
        await tapVisible(tester, find.byKey(const Key('form-next')));
      }
      await tapVisible(tester, find.byKey(const Key('mock-pay')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationDetailScreen), findsOneWidget);
      expect(find.text('Chờ BTC duyệt'), findsOneWidget);
      expect(find.text('1001'), findsNothing);
      repo.status = 'confirmed';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('1001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rejected runner resubmits without creating a payment', (
    tester,
  ) async {
    final repo = FakeRunnerRepository()
      ..status = 'rejected'
      ..paymentStatus = 'paid'
      ..createdBody = validForm();
    await openForm(tester, repo, rejected: true);
    await tapVisible(tester, find.byKey(const Key('form-next')));
    await tapVisible(tester, find.byKey(const Key('form-next')));
    expect(repo.status, 'pending_approval');
    expect(repo.checkoutCalls, 0);
    expect(find.byType(RegistrationDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
