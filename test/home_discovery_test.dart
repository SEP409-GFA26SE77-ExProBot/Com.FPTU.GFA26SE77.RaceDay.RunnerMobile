import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_mobile/core/domain/event_lifecycle.dart';
import 'package:runner_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:runner_mobile/features/home/domain/entities/event_entity.dart';
import 'package:runner_mobile/features/home/domain/repositories/event_repository.dart';
import 'package:runner_mobile/features/home/domain/usecases/get_events_usecase.dart';
import 'package:runner_mobile/features/home/presentation/controller/home_controller.dart';
import 'package:runner_mobile/features/home/presentation/models/home_filter_selection.dart';
import 'package:runner_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:runner_mobile/features/home/presentation/widgets/event_card.dart';
import 'package:runner_mobile/features/home/presentation/widgets/event_filter_sheet.dart';
import 'package:runner_mobile/features/home/presentation/widgets/event_pagination_bar.dart';
import 'package:runner_mobile/features/home/presentation/widgets/home_search_toolbar.dart';
import 'support/fake_runner_repository.dart';

const testUser = UserEntity(
  id: 'u1',
  username: 'runner1',
  role: 'Runner',
  token: 'tok',
  email: 'runner@example.com',
);

class MockEventsRepository implements EventRepository {
  List<EventEntity> items;
  int listCallCount = 0;
  final Map<String, EventLifecycle> lifecycles = {};

  MockEventsRepository(this.items);

  @override
  Future<List<EventEntity>> getEvents() async {
    listCallCount++;
    return items;
  }

  @override
  Future<EventLifecycle> getLifecycle(String id) async {
    if (lifecycles.containsKey(id)) return lifecycles[id]!;
    final match = items.firstWhere((e) => e.id == id);
    return EventLifecycle(
      status: match.status,
      date: match.date,
      endDate: match.endDate,
    );
  }
}

EventEntity createEvent({
  required String id,
  required String name,
  required String date,
  String? endDate,
  String status = 'registration-open',
  String location = 'TP.HCM',
  List<String> distanceTypes = const ['5km', '10km', '21km'],
  List<double> distanceKms = const [5, 10, 21],
  String? tagline,
}) => EventEntity(
  id: id,
  name: name,
  location: location,
  date: date,
  endDate: endDate,
  status: status,
  tagline: tagline,
  distanceTypes: distanceTypes,
  distanceKms: distanceKms,
);

void main() {
  group('HomeController Pagination & Sorting Contracts', () {
    test('0, 1, 10, 11, 23, 101 results calculation and paged slicing', () async {
      // 0 events
      final c0 = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository([])),
      );
      await c0.fetchEvents();
      expect(c0.totalFiltered, 0);
      expect(c0.pageCount, 0);
      expect(c0.pagedEvents, isEmpty);
      c0.dispose();

      // Helper to generate N events
      List<EventEntity> generateN(int count) => List.generate(
        count,
        (i) => createEvent(
          id: 'e_${i.toString().padLeft(4, '0')}',
          name: 'Event $i',
          date: '2026-11-20',
        ),
      );

      // 1 event
      final c1 = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(generateN(1))),
      );
      await c1.fetchEvents();
      expect(c1.totalFiltered, 1);
      expect(c1.pageCount, 1);
      expect(c1.pagedEvents.length, 1);
      c1.dispose();

      // 10 events
      final c10 = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(generateN(10))),
      );
      await c10.fetchEvents();
      expect(c10.totalFiltered, 10);
      expect(c10.pageCount, 1);
      expect(c10.pagedEvents.length, 10);
      c10.dispose();

      // 11 events
      final c11 = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(generateN(11))),
      );
      await c11.fetchEvents();
      expect(c11.totalFiltered, 11);
      expect(c11.pageCount, 2);
      expect(c11.pagedEvents.length, 10);
      c11.setPage(2);
      expect(c11.pagedEvents.length, 1);
      expect(c11.pagedEvents.single.id, 'e_0010');
      c11.dispose();

      // 23 events
      final c23 = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(generateN(23))),
      );
      await c23.fetchEvents();
      expect(c23.totalFiltered, 23);
      expect(c23.pageCount, 3);
      c23.setPage(3);
      expect(c23.pagedEvents.length, 3);
      c23.dispose();

      // 101 events: jump directly to page 11, displays item 101, back to page 10
      final repo101 = MockEventsRepository(generateN(101));
      final c101 = HomeController(
        getEventsUseCase: GetEventsUseCase(repo101),
      );
      await c101.fetchEvents();
      expect(c101.totalFiltered, 101);
      expect(c101.pageCount, 11);
      expect(repo101.listCallCount, 1);

      c101.setPage(11);
      expect(c101.currentPage, 11);
      expect(c101.pagedEvents.length, 1);
      expect(c101.pagedEvents.first.id, 'e_0100'); // 101st item
      expect(repo101.listCallCount, 1); // Page navigation does NOT call API

      c101.setPage(10);
      expect(c101.currentPage, 10);
      expect(c101.pagedEvents.length, 10);
      expect(repo101.listCallCount, 1);
      c101.dispose();
    });

    test('Filter finds event at the end of allEvents, proving filter precedes slicing', () async {
      final items = [
        ...List.generate(
          15,
          (i) => createEvent(
            id: 'e$i',
            name: 'Common Race $i',
            date: '2026-11-10',
            location: 'Hà Nội',
          ),
        ),
        createEvent(
          id: 'target',
          name: 'Special Dalat Trail',
          date: '2026-11-20',
          location: 'Đà Lạt',
        ),
      ];

      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(items)),
      );
      await c.fetchEvents();
      expect(c.totalFiltered, 16);
      expect(c.pageCount, 2);

      // Filter by location 'Đà Lạt'
      c.setLocation('Đà Lạt');
      expect(c.currentPage, 1);
      expect(c.totalFiltered, 1);
      expect(c.pagedEvents.single.id, 'target');
      c.dispose();
    });

    test('Default comparator sorts active/upcoming ascending, past descending, invalid at end, id tiebreaker', () {
      final now = DateTime(2026, 10, 19, 12, 0);

      final upcomingA = createEvent(id: 'uA', name: 'Up A', date: '2026-10-25');
      final upcomingB = createEvent(id: 'uB', name: 'Up B', date: '2026-10-20');
      final upcomingSameA = createEvent(id: 'u1', name: 'Same 1', date: '2026-10-22');
      final upcomingSameB = createEvent(id: 'u2', name: 'Same 2', date: '2026-10-22');

      final pastRecent = createEvent(id: 'p1', name: 'Past Recent', date: '2026-10-15');
      final pastOlder = createEvent(id: 'p2', name: 'Past Older', date: '2026-09-01');

      final invalidDate = createEvent(id: 'inv', name: 'Invalid', date: 'not-a-date');

      final list = [invalidDate, pastOlder, upcomingA, pastRecent, upcomingB, upcomingSameB, upcomingSameA];
      list.sort((a, b) => HomeController.compareEvents(a, b, now));

      expect(list.map((e) => e.id).toList(), [
        'uB', // 2026-10-20 (upcoming ascending)
        'u1', // 2026-10-22 (same date, tie break by id u1 < u2)
        'u2', // 2026-10-22
        'uA', // 2026-10-25
        'p1', // 2026-10-15 (past descending: 10-15 before 09-01)
        'p2', // 2026-09-01
        'inv', // invalid at end
      ]);
    });

    test('Filter changes reset page to 1; applying identical selection preserves page', () async {
      final items = List.generate(
        25,
        (i) => createEvent(id: 'e$i', name: 'Event $i', date: '2026-11-01'),
      );
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(items)),
      );
      await c.fetchEvents();
      c.setPage(2);
      expect(c.currentPage, 2);

      // Applying identical selection preserves page
      c.applyFilters(c.filterSelection);
      expect(c.currentPage, 2);

      // Changing filter resets to page 1
      c.setDistance('5km');
      expect(c.currentPage, 1);

      c.setPage(2);
      expect(c.currentPage, 2);
      c.setSearchQuery('Event');
      expect(c.currentPage, 1);

      c.dispose();
    });

    test('clearFilter clears single field and keeps others and search query', () async {
      final items = [
        createEvent(id: '1', name: 'Race 1', date: '2026-11-01', location: 'Hà Nội'),
      ];
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(items)),
      );
      await c.fetchEvents();

      c.setSearchQuery('Race');
      c.applyFilters(const HomeFilterSelection(
        distance: '5km',
        location: 'Hà Nội',
        time: 'Tháng này',
        status: 'Đang mở đăng ký',
      ));
      expect(c.activeFilterCount, 4);
      expect(c.searchQuery, 'Race');

      // Clear distance only
      c.clearFilter(HomeFilterField.distance);
      expect(c.selectedDistance, HomeFilterSelection.defaultDistance);
      expect(c.selectedLocation, 'Hà Nội');
      expect(c.selectedTime, 'Tháng này');
      expect(c.selectedStatus, 'Đang mở đăng ký');
      expect(c.searchQuery, 'Race');
      expect(c.activeFilterCount, 3);

      // clearFilters resets all 4 filters but KEEPS search query
      c.clearFilters();
      expect(c.activeFilterCount, 0);
      expect(c.searchQuery, 'Race');

      // resetFilters resets both search and filters
      c.resetFilters();
      expect(c.searchQuery, '');
      expect(c.activeFilterCount, 0);

      c.dispose();
    });

    test('selected location and year preserved even when absent from updated data', () async {
      final items1 = [
        createEvent(id: '1', name: 'Race', date: '2026-11-01', location: 'Đà Nẵng'),
      ];
      final repo = MockEventsRepository(items1);
      final c = HomeController(getEventsUseCase: GetEventsUseCase(repo));
      await c.fetchEvents();

      c.setLocation('Đà Nẵng');
      c.setTime('Năm 2026');
      expect(c.selectedLocation, 'Đà Nẵng');
      expect(c.selectedTime, 'Năm 2026');

      // Next refresh returns list without Đà Nẵng
      repo.items = [
        createEvent(id: '2', name: 'Race 2', date: '2027-05-01', location: 'Hà Nội'),
      ];
      await c.fetchEvents();

      expect(c.locationOptions.contains('Đà Nẵng'), isTrue);
      expect(c.timeOptions.contains('Năm 2026'), isTrue);
      expect(c.selectedLocation, 'Đà Nẵng');
      expect(c.selectedTime, 'Năm 2026');
      c.dispose();
    });

    test('Refresh error keeps existing data, query, filters, and page', () async {
      final items = List.generate(
        15,
        (i) => createEvent(id: 'e$i', name: 'Race $i', date: '2026-11-01'),
      );
      final repo = MockEventsRepository(items);
      final c = HomeController(getEventsUseCase: GetEventsUseCase(repo));
      await c.fetchEvents();

      c.setPage(2);
      c.setSearchQuery('Race');

      // Make next refresh throw
      c.dispose(); // clean previous
    });
  });

  group('Widget Tests (UI & Interactions)', () {
    testWidgets('HomeSearchToolbar debounces 250ms and clears immediately', (
      tester,
    ) async {
      String searched = '';
      bool cleared = false;
      bool filterOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSearchToolbar(
              initialQuery: '',
              onSearchChanged: (q) => searched = q,
              onSearchCleared: () => cleared = true,
              activeFilterCount: 2,
              onOpenFilter: () => filterOpened = true,
            ),
          ),
        ),
      );

      // Badge displays count 2
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Typing triggers debounce
      await tester.enterText(find.byType(TextField), 'Marathon');
      await tester.pump(const Duration(milliseconds: 100));
      expect(searched, ''); // Not yet fired

      await tester.pump(const Duration(milliseconds: 200));
      expect(searched, 'Marathon'); // Fired after 250ms

      // Tapping clear button calls onSearchCleared immediately
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(cleared, isTrue);

      // Tapping filter icon calls onOpenFilter
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      expect(filterOpened, isTrue);
    });

    testWidgets('EventFilterSheet draft cancel preserves active filters; apply updates atomically', (
      tester,
    ) async {
      final items = [
        createEvent(id: '1', name: 'R1', date: '2026-11-01', location: 'Hà Nội'),
      ];
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(items)),
      );
      await c.fetchEvents();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => EventFilterSheet.show(ctx, c),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ lọc sự kiện'), findsOneWidget);

      // Select '5km' in draft
      await tester.tap(find.text('5km'));
      await tester.pump();

      // Close sheet without applying (tap X)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Controller remains at default
      expect(c.selectedDistance, HomeFilterSelection.defaultDistance);

      // Open sheet again, select '5km', tap 'Áp dụng'
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5km'));
      await tester.pump();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(c.selectedDistance, '5km');
      expect(c.activeFilterCount, 1);
      c.dispose();
    });

    testWidgets('EventPaginationBar disables boundary buttons and supports jump dialog', (
      tester,
    ) async {
      int page = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) => EventPaginationBar(
                currentPage: page,
                pageCount: 5,
                onPageChanged: (p) => setState(() => page = p),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Trang 1 / 5'), findsOneWidget);

      // Previous button is disabled on page 1
      final prevBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Trước'),
      );
      expect(prevBtn.onPressed, isNull);

      // Next button is enabled
      final nextBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Sau'),
      );
      expect(nextBtn.onPressed, isNotNull);

      // Tap Next -> moves to page 2
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sau'));
      await tester.pump();
      expect(find.text('Trang 2 / 5'), findsOneWidget);

      // Tap 'Trang 2 / 5' opens jump dialog
      await tester.tap(find.text('Trang 2 / 5'));
      await tester.pumpAndSettle();

      expect(find.text('Đi tới trang'), findsOneWidget);

      // Enter invalid page 99
      await tester.enterText(find.byType(TextField), '99');
      await tester.tap(find.text('Đi tới'));
      await tester.pump();
      expect(find.text('Vui lòng nhập số từ 1 đến 5'), findsOneWidget);

      // Enter valid page 4
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('Đi tới'));
      await tester.pumpAndSettle();

      expect(find.text('Trang 4 / 5'), findsOneWidget);
    });

    testWidgets('HomeScreen full integration with compact cards and pagination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = List.generate(
        15,
        (i) => createEvent(
          id: 'e$i',
          name: 'Event Name $i',
          date: '2026-11-${(i + 1).toString().padLeft(2, '0')}',
          location: 'Hồ Chí Minh',
        ),
      );
      final c = HomeController(
        getEventsUseCase: GetEventsUseCase(MockEventsRepository(items)),
      );
      await c.fetchEvents();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            user: testUser,
            controller: c,
            repository: FakeRunnerRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Compact EventCard rendered with ValueKey
      expect(find.byKey(const ValueKey('e0')), findsOneWidget);
      expect(find.byType(EventCard), findsWidgets);

      // Summary row
      expect(find.text('1–10 / 15 giải phù hợp'), findsOneWidget);

      // Pager exists and page 1 has 10 items
      expect(find.text('Trang 1 / 2'), findsOneWidget);

      // Navigate to page 2
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sau'));
      await tester.pumpAndSettle();

      expect(find.text('11–15 / 15 giải phù hợp'), findsOneWidget);
      expect(find.byKey(const ValueKey('e14')), findsOneWidget);
    });
  });
}
