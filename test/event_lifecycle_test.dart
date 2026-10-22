import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runner_mobile/core/domain/event_lifecycle.dart';
import 'package:runner_mobile/core/network/api_client.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:runner_mobile/features/home/data/datasources/event_remote_data_source.dart';
import 'package:runner_mobile/features/home/data/models/event_model.dart';
import 'package:runner_mobile/features/home/domain/entities/event_entity.dart';
import 'package:runner_mobile/features/home/domain/repositories/event_repository.dart';
import 'package:runner_mobile/features/home/domain/usecases/get_events_usecase.dart';
import 'package:runner_mobile/features/home/presentation/controller/home_controller.dart';
import 'package:runner_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:runner_mobile/features/runner/data/runner_mappers.dart';
import 'package:runner_mobile/features/runner/domain/runner_models.dart';
import 'package:runner_mobile/features/runner/presentation/screens/event_detail_screen.dart';
import 'support/fake_runner_repository.dart';

const user = UserEntity(
  id: 'u1',
  username: 'runner',
  role: 'Runner',
  token: 'test',
);

void backgroundAndResume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

final instant = DateTime.utc(2026, 10, 19, 8);

EventEntity listItem(String id) => EventModel.fromJson({
  'id': id,
  'name': 'Race $id',
  'location': 'Hà Nội',
  'date': '2099-12-01',
  'status': 'registration-open',
});

EventLifecycle lifecycle({
  DateTime? closesAt,
  String status = 'registration-open',
}) => EventLifecycle(status: status, date: '2099-12-01', closesAt: closesAt);

class ControlledEvents implements EventRepository {
  List<EventEntity> items;
  int listCalls = 0;
  final requests = <(String, Completer<EventLifecycle>)>[];
  ControlledEvents(int count)
    : items = List.generate(count, (i) => listItem('e$i'));
  @override
  Future<List<EventEntity>> getEvents() async {
    listCalls++;
    return List.of(items);
  }

  @override
  Future<EventLifecycle> getLifecycle(String id) {
    final result = Completer<EventLifecycle>();
    requests.add((id, result));
    return result.future;
  }
}

class DetailEvents extends FakeRunnerRepository {
  DateTime? closes;
  int reads = 0;
  @override
  Future<RaceDetail> event(String id) async {
    reads++;
    final base = await super.event(id);
    return RaceDetail(
      id: id,
      name: base.name,
      location: base.location,
      date: '2099-12-01',
      status: 'registration-open',
      organizerName: base.organizerName,
      organizerEmail: base.organizerEmail,
      organizerPhone: base.organizerPhone,
      distances: base.distances,
      closesAt: closes,
    );
  }
}

class DeferredLists extends ControlledEvents {
  final lists = <Completer<List<EventEntity>>>[];
  DeferredLists() : super(0);
  @override
  Future<List<EventEntity>> getEvents() {
    final result = Completer<List<EventEntity>>();
    lists.add(result);
    return result.future;
  }
}

void main() {
  testWidgets('older list response cannot overwrite newer refresh', (
    tester,
  ) async {
    final repo = DeferredLists();
    final c = HomeController(
      getEventsUseCase: GetEventsUseCase(repo),
      clock: () => instant,
    );
    final oldLoad = c.fetchEvents();
    final newLoad = c.fetchEvents();
    repo.lists[1].complete([listItem('new')]);
    await newLoad;
    repo.lists[0].complete([listItem('old')]);
    await oldLoad;
    expect(c.allEvents.single.id, 'new');
    expect(repo.requests.single.$1, 'new');
    c.dispose();
    repo.requests.single.$2.complete(lifecycle());
    await tester.pump();
  });

  testWidgets(
    'detail updates dates and status without invalidating selected year',
    (tester) async {
      final repo = ControlledEvents(1);
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(repo),
        clock: () => instant,
      );
      await c.fetchEvents();
      c.setTime('Năm 2099');
      repo.requests.single.$2.complete(
        const EventLifecycle(
          status: 'closed',
          date: '2098-01-01',
          endDate: '2098-01-02',
        ),
      );
      await tester.pump();
      expect(c.selectedTime, 'Năm 2099');
      expect(c.timeOptions, contains(c.selectedTime));
      expect(c.filteredEvents, isEmpty);
      expect(c.allEvents.single.date, '2098-01-01');
      expect(c.allEvents.single.endDate, '2098-01-02');
      expect(c.allEvents.single.status, 'closed');
      c.dispose();
    },
  );

  test('clock boundary includes local midnight and compares UTC offsets', () {
    final now = DateTime(2026, 10, 19, 23, 59, 59);
    expect(nextLifecycleChange([lifecycle()], now), DateTime(2026, 10, 20));
    final event = lifecycle(
      closesAt: DateTime.parse('2026-10-19T15:00:00+07:00'),
    );
    expect(event.stateAt(instant), EventRegistrationState.expired);
  });
  test('opening is inclusive; closing and package expiry are exclusive', () {
    final open = instant;
    final close = instant.add(const Duration(hours: 1));
    final event = EventLifecycle(
      status: 'registration-open',
      date: '2099-12-01',
      opensAt: open,
      closesAt: close,
    );
    expect(
      event.stateAt(open.subtract(const Duration(microseconds: 1))),
      EventRegistrationState.scheduled,
    );
    expect(event.stateAt(open), EventRegistrationState.open);
    expect(
      event.stateAt(open.add(const Duration(microseconds: 1))),
      EventRegistrationState.open,
    );
    expect(
      event.stateAt(close.subtract(const Duration(microseconds: 1))),
      EventRegistrationState.open,
    );
    expect(event.stateAt(close), EventRegistrationState.expired);
    expect(
      event.stateAt(close.add(const Duration(microseconds: 1))),
      EventRegistrationState.expired,
    );
    final package = EventLifecycle(
      status: 'registration-open',
      date: '2099-12-01',
      packageExpiresAt: close,
    );
    expect(
      package.stateAt(close.subtract(const Duration(microseconds: 1))),
      EventRegistrationState.open,
    );
    expect(package.stateAt(close), EventRegistrationState.suspended);
    expect(
      package.stateAt(close.add(const Duration(seconds: 1))),
      EventRegistrationState.suspended,
    );
  });

  test('terminal states, local end date and suspension take precedence', () {
    for (final entry in {
      'completed': EventRegistrationState.ended,
      'cancelled': EventRegistrationState.cancelled,
      'suspended': EventRegistrationState.suspended,
      'closed': EventRegistrationState.closed,
      'approved': EventRegistrationState.upcoming,
    }.entries) {
      expect(lifecycle(status: entry.key).stateAt(instant), entry.value);
    }
    const ended = EventLifecycle(
      status: 'registration-open',
      date: '2026-10-18',
    );
    expect(ended.stateAt(DateTime(2026, 10, 19)), EventRegistrationState.ended);
    const multiDay = EventLifecycle(
      status: 'registration-open',
      date: '2026-10-18',
      endDate: '2026-10-20',
    );
    expect(
      multiDay.stateAt(DateTime(2026, 10, 20, 23, 59)),
      EventRegistrationState.open,
    );
    expect(
      multiDay.stateAt(DateTime(2026, 10, 21)),
      EventRegistrationState.ended,
    );
    expect(
      lifecycle(status: 'closed', closesAt: instant).stateAt(instant),
      EventRegistrationState.expired,
    );
  });

  test(
    'list missing deadlines is unknown; verified null deadlines can open',
    () async {
      final item = listItem('e1');
      expect(item.lifecycle.stateAt(instant), EventRegistrationState.loading);
      final source = EventRemoteDataSourceImpl(
        client: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/v1/event/e1');
            return http.Response(
              jsonEncode({
                'id': 'e1',
                'status': 'registration-open',
                'date': '2099-12-01',
                'registrationOpensAtUtc': null,
                'registrationClosesAtUtc': null,
                'packageExpiresAtUtc': null,
              }),
              200,
            );
          }),
        ),
      );
      expect(
        item
            .withLifecycle(await source.getLifecycle('e1'))
            .lifecycle
            .stateAt(instant),
        EventRegistrationState.open,
      );
      final invalid = EventRemoteDataSourceImpl(
        client: ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'id': 'e1',
                'status': 'registration-open',
                'date': '2099-12-01',
              }),
              200,
            ),
          ),
        ),
      );
      await expectLater(invalid.getLifecycle('e1'), throwsFormatException);
    },
  );

  testWidgets(
    'progressive enrichment fixes open badge/filter and isolates errors',
    (tester) async {
      final repo = ControlledEvents(2);
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(repo),
        clock: () => instant,
      );
      await c.fetchEvents();
      expect(c.isLoading, isFalse);
      expect(c.allEvents.length, 2);
      expect(c.statusFor(c.allEvents.first), 'Đang kiểm tra trạng thái');
      c.setStatus('Đang mở đăng ký');
      expect(c.filteredEvents, isEmpty);
      repo.requests[0].$2.complete(lifecycle(closesAt: instant));
      repo.requests[1].$2.completeError(Exception('offline'));
      await tester.pump();
      expect(c.filteredEvents, isEmpty);
      expect(c.error, isNull);
      expect(c.statusFor(c.allEvents[0]), 'Đã hết hạn đăng ký');
      expect(c.statusFor(c.allEvents[1]), 'Chưa xác định trạng thái');
      final detail = raceDetailFromJson({
        'id': 'e0',
        'name': 'Race',
        'date': '2099-12-01',
        'status': 'registration-open',
        'registrationClosesAtUtc': instant.toIso8601String(),
      });
      expect(
        detail.lifecycle.stateAt(instant),
        c.allEvents[0].lifecycle.stateAt(instant),
      );
      expect(detail.acceptsAt(instant), isFalse);
      c.setStatus('Đã đóng đăng ký');
      expect(c.filteredEvents.single.id, 'e0');
      c.dispose();
    },
  );

  testWidgets('four requests maximum across refresh; stale responses ignored', (
    tester,
  ) async {
    final repo = ControlledEvents(8);
    final c = HomeController(
      getEventsUseCase: GetEventsUseCase(repo),
      clock: () => instant,
    );
    await c.fetchEvents();
    expect(repo.requests.length, 4);
    await c.fetchEvents();
    expect(repo.requests.length, 4);
    // Finishing an old request frees one slot, but cannot update the new list.
    repo.requests[2].$2.complete(lifecycle(status: 'closed'));
    await tester.pump();
    expect(repo.requests.length, 5);
    expect(c.allEvents[2].lifecycleLoadState, LifecycleLoadState.loading);
    repo.requests[4].$2.complete(lifecycle());
    await tester.pump();
    expect(repo.requests.length, 6);
    expect(c.allEvents.first.lifecycleLoadState, LifecycleLoadState.ready);
    c.dispose();
    for (final request in repo.requests) {
      if (!request.$2.isCompleted) request.$2.complete(lifecycle());
    }
    await tester.pump();
    expect(repo.requests.length, 6);
  });

  testWidgets(
    'clock boundary updates filter without API polling, pause and dispose stop timers',
    (tester) async {
      var now = instant;
      final repo = ControlledEvents(1);
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(repo),
        clock: () => now,
      );
      await c.fetchEvents();
      repo.requests.single.$2.complete(
        lifecycle(closesAt: now.add(const Duration(seconds: 10))),
      );
      await tester.pump();
      c.setStatus('Đang mở đăng ký');
      expect(c.filteredEvents.length, 1);
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(c.filteredEvents, isEmpty);
      expect(repo.listCalls, 1);
      expect(repo.requests.length, 1);
      c.setActive(false);
      c.dispose();
    },
  );

  testWidgets('ended filter uses date even when raw status is open', (
    tester,
  ) async {
    final repo = ControlledEvents(1);
    final c = HomeController(
      getEventsUseCase: GetEventsUseCase(repo),
      clock: () => instant,
    );
    await c.fetchEvents();
    repo.requests.single.$2.complete(
      const EventLifecycle(status: 'registration-open', date: '2026-10-18'),
    );
    await tester.pump();
    c.setStatus('Đã kết thúc');
    expect(c.filteredEvents.length, 1);
    c.dispose();
  });

  testWidgets(
    'detail expires while visible and keeps existing registration accessible',
    (tester) async {
      var now = instant;
      final repo = DetailEvents()
        ..hasRegistration = false
        ..closes = now.add(const Duration(seconds: 10));
      await tester.pumpWidget(
        MaterialApp(
          home: EventDetailScreen(
            eventId: 'e1',
            user: user,
            repository: repo,
            clock: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Đăng ký cự ly đã chọn');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('Đã hết hạn đăng ký'), findsOneWidget);
      expect(repo.reads, 1);
      repo.hasRegistration = true;
      repo.status = 'confirmed';
      backgroundAndResume(tester);
      await tester.pumpAndSettle();
      expect(repo.reads, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem vé của tôi'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('registration click rechecks time before scheduled rebuild', (
    tester,
  ) async {
    var now = instant;
    final repo = DetailEvents()
      ..hasRegistration = false
      ..closes = now.add(const Duration(hours: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: EventDetailScreen(
          eventId: 'e1',
          user: user,
          repository: repo,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    now = now.add(const Duration(hours: 1));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Đăng ký cự ly đã chọn'),
    );
    await tester.pump();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đăng ký cự ly đã chọn'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'home refreshes on return, resume and pull-to-refresh, retaining filters',
    (tester) async {
      final repo = ControlledEvents(1);
      final c = HomeController(getEventsUseCase: GetEventsUseCase(repo));
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            user: user,
            controller: c,
            repository: DetailEvents(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.requests.last.$2.complete(lifecycle());
      await tester.pumpAndSettle();
      c.setSearchQuery('Race');
      await tester.pump();
      await tester.tap(find.text('Race e0').first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.listCalls, 2);
      expect(c.searchQuery, 'Race');
      backgroundAndResume(tester);
      await tester.pumpAndSettle();
      expect(repo.listCalls, 3);
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pump();
      expect(repo.listCalls, 4);
      expect(c.searchQuery, 'Race');
      await tester.pumpWidget(const SizedBox.shrink());
      for (final request in repo.requests) {
        if (!request.$2.isCompleted) request.$2.complete(lifecycle());
      }
      await tester.pump();
    },
  );
}
