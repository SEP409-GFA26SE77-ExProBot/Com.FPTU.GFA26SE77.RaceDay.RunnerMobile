import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runner_mobile/core/network/api_client.dart';
import 'package:runner_mobile/features/runner/data/runner_mappers.dart';
import 'package:runner_mobile/features/runner/data/runner_repository_impl.dart';
import 'package:runner_mobile/features/runner/data/payment_callbacks.dart';
import 'package:runner_mobile/features/runner/domain/ticket_price_preview.dart';
import 'package:runner_mobile/features/runner/presentation/controllers/payment_controller.dart';
import 'support/fake_runner_repository.dart';

Map<String, dynamic> detail() => {
  'id': 'e1',
  'name': 'Race',
  'status': 'registration-open',
  'date': '2026-12-01',
  'location': 'Ha Noi',
  'registrationOpensAtUtc': '2026-10-01T00:00:00Z',
  'registrationClosesAtUtc': '2026-11-01T00:00:00Z',
  'packageExpiresAtUtc': '2026-12-01T00:00:00Z',
  'ticketPricing': {
    'byDistanceName': {
      'Half': {
        'basePrice': 1000000,
        'phases': [
          {
            'key': 'early',
            'name': 'Early bird',
            'price': 800000,
            'dateFrom': '2026-10-15',
            'dateTo': '2026-10-15',
          },
        ],
      },
    },
  },
  'distances': [
    {
      'id': 'd1',
      'name': 'Half',
      'distanceKm': 21.1,
      'price': 1000000,
      'capacity': 100,
      'registeredCount': 10,
      'currency': 'VND',
    },
  ],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'current event detail reads basePrice without legacy price or route fields',
    () {
      final json = detail();
      final distance =
          (json['distances'] as List).single as Map<String, dynamic>;
      distance.remove('price');
      distance['basePrice'] = 1000000;
      final race = raceDetailFromJson(json, utcNow: DateTime.utc(2026, 10, 15));
      expect(race.distances.single.price, 1000000);
      expect(race.distances.single.estimatedPrice, 800000);
      expect(race.distances.single.km, 21.1);
    },
  );

  test('basePrice takes precedence including a free distance', () {
    final json = detail()..['ticketPricing'] = null;
    final distance = (json['distances'] as List).single as Map<String, dynamic>;
    distance['basePrice'] = 0;
    final race = raceDetailFromJson(json);
    expect(race.distances.single.price, 0);
    expect(race.distances.single.estimatedPrice, 0);
  });

  test('missing prices are not silently displayed as free', () {
    final json = detail();
    final distance = (json['distances'] as List).single as Map<String, dynamic>;
    distance.remove('price');
    json['distances'] = [<String, dynamic>{...distance, 'basePrice': null}];
    expect(() => raceDetailFromJson(json), throwsA(isA<FormatException>()));
  });

  test(
    'original detail DTO allows registration without any added backend fields',
    () {
      final race = raceDetailFromJson(
        detail(),
        utcNow: DateTime.utc(2026, 10, 14, 17),
      );
      expect(race.acceptsAt(DateTime.utc(2026, 10, 15)), isTrue);
      expect(race.acceptsAt(DateTime.utc(2026, 9, 30)), isFalse);
      expect(race.acceptsAt(DateTime.utc(2026, 11, 1)), isFalse);
      expect(race.distances.single.estimatedPrice, 800000);
      expect(race.distances.single.phaseName, 'Early bird');
      final closed = detail()..['status'] = 'closed';
      expect(
        raceDetailFromJson(closed).acceptsAt(DateTime.utc(2026, 10, 15)),
        isFalse,
      );
      final expired = detail()
        ..['packageExpiresAtUtc'] = '2026-10-15T00:00:00Z';
      expect(
        raceDetailFromJson(expired).acceptsAt(DateTime.utc(2026, 10, 15)),
        isFalse,
      );
    },
  );

  test(
    'price preview follows inclusive Vietnam dates, then falls back to base',
    () {
      final pricing = detail()['ticketPricing'];
      expect(
        ticketPricePreview(
          pricing,
          'Half',
          1000000,
          DateTime.utc(2026, 10, 14, 16, 59),
        ).price,
        1000000,
      );
      expect(
        ticketPricePreview(
          pricing,
          'Half',
          1000000,
          DateTime.utc(2026, 10, 14, 17),
        ).price,
        800000,
      );
      expect(
        ticketPricePreview(
          pricing,
          'Half',
          1000000,
          DateTime.utc(2026, 10, 15, 16, 59),
        ).price,
        800000,
      );
      expect(
        ticketPricePreview(
          pricing,
          'Half',
          1000000,
          DateTime.utc(2026, 10, 15, 17),
        ).price,
        1000000,
      );
      expect(
        ticketPricePreview(null, 'Half', 900000, DateTime.utc(2026)).price,
        900000,
      );
    },
  );

  test('legacy ticketPricing prefers promotional phase over standard', () {
    final pricing = {
      'phases': [
        {
          'key': 'standard',
          'dateFrom': '2026-01-01',
          'dateTo': '2026-12-31',
          'pricesByDistanceName': {'Half': 1000000},
        },
        {
          'key': 'early',
          'name': 'Early bird',
          'dateFrom': '2026-10-01',
          'dateTo': '2026-10-31',
          'pricesByDistanceName': {'Half': 700000},
        },
      ],
    };
    expect(
      ticketPricePreview(
        pricing,
        'Half',
        1200000,
        DateTime.utc(2026, 10, 15),
      ).price,
      700000,
    );
    expect(
      ticketPricePreview(
        pricing,
        'Half',
        1200000,
        DateTime.utc(2026, 11, 15),
      ).price,
      1000000,
    );
    expect(
      ticketPricePreview(pricing, 'Half', 1200000, DateTime.utc(2027)).price,
      1000000,
    );
  });

  test(
    'callbacks use client page or existing status endpoint, never invented API routes',
    () {
      final native = PaymentCallbacks.resolve(
        apiBase: 'https://api.example.com',
      );
      expect(native.returnUrl, 'https://api.example.com/api/v1/payment/status');
      expect(native.cancelUrl, native.returnUrl);
      final web = PaymentCallbacks.resolve(
        apiBase: 'https://api.example.com',
        webAppUri: Uri.parse(
          'https://runner.example.com/mobile/#/registration',
        ),
      );
      expect(
        web.returnUrl,
        'https://runner.example.com/mobile/payment-return.html',
      );
      final configured = PaymentCallbacks.resolve(
        apiBase: 'https://api.example.com',
        returnUrl: 'https://runner.example.com/payment-return.html',
      );
      expect(configured.cancelUrl, configured.returnUrl);
      expect(
        () => PaymentCallbacks.resolve(
          apiBase: 'https://api.example.com',
          returnUrl: 'raceday://paid',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'repository uses existing routes and preserves the server quoted amount',
    () async {
      final registration = {
        'id': 'r1',
        'eventId': 'e1',
        'distanceId': 'd1',
        'status': 'pending_payment',
        'price': 825000,
        'currency': 'VND',
      };
      final payment = {
        'id': 'p1',
        'registrationId': 'r1',
        'status': 'pending',
        'amount': 825000,
        'currency': 'VND',
        'createdAtUtc': '2026-10-15T00:00:00Z',
        'checkoutUrl': 'https://pay.example.com/link',
      };
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          final path = request.url.path;
          Object response;
          switch (path) {
            case '/api/v1/event/e1':
              response = detail();
            case '/api/v1/event/e1/registrations':
              final body = jsonDecode(request.body) as Map;
              expect(body.containsKey('price'), isFalse);
              response = registration;
            case '/api/v1/payment/checkout':
              final body = jsonDecode(request.body) as Map;
              expect(body['registrationId'], 'r1');
              expect(body['returnUrl'], endsWith('/api/v1/payment/status'));
              expect(body['cancelUrl'], body['returnUrl']);
              expect(body.containsKey('amount'), isFalse);
              response = payment;
            default:
              fail('Unexpected API route: $path');
          }
          return http.Response(jsonEncode(response), 200);
        }),
      );
      final repo = RunnerRepositoryImpl(token: 'token', client: api);
      final race = await repo.event('e1');
      expect(race.status, 'registration-open');
      final reg = await repo.createRegistration('e1', {
        'distanceId': 'd1',
        'liabilityAccepted': true,
      });
      expect(reg.price, 825000);
      expect((await repo.checkout(reg.id)).amount, 825000);
    },
  );

  test(
    'changing from mock to live after opening screen prevents test request',
    () async {
      final repo = FakeRunnerRepository();
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh();
      repo.mode = 'live';
      await c.testPayment();
      expect(repo.mockCalls, 0);
      expect(c.isMock, isFalse);
      expect(c.busy, isFalse);
      c.dispose();
    },
  );

  test(
    'saved paid state is read without pretending sync repairs registration',
    () async {
      final repo = FakeRunnerRepository()..paymentStatus = 'paid';
      final c = PaymentController(
        repository: repo,
        registrationId: 'r1',
        userId: 'u1',
      );
      await c.refresh(prepareCheckout: true);
      await c.refresh();
      await c.testPayment();
      expect(c.registration!.status, 'pending_payment');
      expect(c.needsReconciliation, isTrue);
      expect(repo.mockCalls, 0);
      expect(repo.checkoutCalls, 0);
      c.dispose();
    },
  );
}
