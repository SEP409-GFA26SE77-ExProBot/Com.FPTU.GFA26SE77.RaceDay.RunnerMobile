import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../../../../core/domain/event_lifecycle.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/usecases/get_events_usecase.dart';
import '../../data/repositories/event_repository_impl.dart';
import '../models/home_filter_selection.dart';

class HomeController extends ChangeNotifier {
  static const int pageSize = 10;

  final GetEventsUseCase _getEventsUseCase;
  final DateTime Function() _clock;
  bool _disposed = false;
  bool _active = true;
  int _generation = 0, _activeRequests = 0;
  int _currentGenPendingRequests = 0;
  final _pending = Queue<(int, EventEntity)>();
  Timer? _boundaryTimer;

  List<EventEntity> _allEvents = [];
  List<EventEntity> get allEvents => _allEvents;
  List<EventEntity> filteredEvents = [];

  List<EventEntity> get bannerEvents => filteredEvents.take(3).toList();

  String statusFor(EventEntity event) =>
      event.lifecycle.stateAt(_clock()).label;

  // Pagination state
  int currentPage = 1;
  int get totalFiltered => filteredEvents.length;
  int get pageCount =>
      totalFiltered == 0 ? 0 : (totalFiltered / pageSize).ceil();

  List<EventEntity> get pagedEvents {
    if (filteredEvents.isEmpty) return const [];
    final start = (currentPage - 1) * pageSize;
    if (start >= filteredEvents.length) return const [];
    final end = (start + pageSize).clamp(0, filteredEvents.length);
    return filteredEvents.sublist(start, end);
  }

  // Loading & refresh state
  bool isInitialLoading = true;
  bool isRefreshing = false;
  bool get isLoading => isInitialLoading || isRefreshing;
  String? error;
  String? refreshError;

  // Verification state of current generation
  int get pendingLifecycleCount => _currentGenPendingRequests;
  bool get isResolvingLifecycle => _currentGenPendingRequests > 0;
  bool get hasLifecycleFailures => _allEvents.any(
    (e) => e.lifecycle.loadState == LifecycleLoadState.failed,
  );

  // Search & filter state
  String searchQuery = '';
  String selectedDistance = HomeFilterSelection.defaultDistance;
  String selectedLocation = HomeFilterSelection.defaultLocation;
  String selectedTime = HomeFilterSelection.defaultTime;
  String selectedStatus = HomeFilterSelection.defaultStatus;

  HomeFilterSelection get filterSelection => HomeFilterSelection(
    distance: selectedDistance,
    location: selectedLocation,
    time: selectedTime,
    status: selectedStatus,
  );

  int get activeFilterCount => filterSelection.activeCount;
  bool get hasActiveFilters => activeFilterCount > 0;

  List<String> get distanceOptions => [
    'Tất cả cự ly',
    '5km',
    '10km',
    '21km',
    '42km',
    'Khác',
  ];

  List<String> get locationOptions => [
    'Tất cả địa điểm',
    ...(_allEvents
        .map((e) => e.location)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort()),
    if (selectedLocation != 'Tất cả địa điểm' &&
        !_allEvents.any((e) => e.location == selectedLocation))
      selectedLocation,
  ];

  List<String> get timeOptions => [
    'Tất cả thời gian',
    'Sắp diễn ra',
    'Tháng này',
    ...(_allEvents
            .map((e) => DateTime.tryParse(e.date)?.year)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort())
        .map((y) => 'Năm $y'),
    if (selectedTime.startsWith('Năm ') &&
        !_allEvents.any(
          (e) =>
              DateTime.tryParse(e.date)?.year.toString() ==
              selectedTime.substring(4),
        ))
      selectedTime,
  ];

  final statusOptions = [
    'Tất cả trạng thái',
    'Đang mở đăng ký',
    'Sắp mở đăng ký',
    'Đã đóng đăng ký',
    'Đã kết thúc',
  ];

  HomeController({
    GetEventsUseCase? getEventsUseCase,
    DateTime Function()? clock,
  }) : _getEventsUseCase =
           getEventsUseCase ?? GetEventsUseCase(EventRepositoryImpl()),
       _clock = clock ?? DateTime.now;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pending.clear();
    _currentGenPendingRequests = 0;
    _boundaryTimer?.cancel();
    super.dispose();
  }

  void setActive(bool value) {
    _active = value;
    if (value) {
      _applyFilters();
    } else {
      _boundaryTimer?.cancel();
    }
  }

  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    if (_disposed || !_active) return;
    final now = _clock();
    final next = nextLifecycleChange(_allEvents.map((e) => e.lifecycle), now);
    _boundaryTimer = Timer(next.difference(now), _applyFilters);
  }

  static int compareEvents(EventEntity a, EventEntity b, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final aStart = DateTime.tryParse(a.date);
    final bStart = DateTime.tryParse(b.date);
    final aEnd = DateTime.tryParse(a.endDate ?? a.date);
    final bEnd = DateTime.tryParse(b.endDate ?? b.date);

    // 3. Ngày không parse được: cuối danh sách
    if (aStart == null && bStart == null) return a.id.compareTo(b.id);
    if (aStart == null) return 1;
    if (bStart == null) return -1;

    final aIsOver = (aEnd != null && aEnd.isBefore(today));
    final bIsOver = (bEnd != null && bEnd.isBefore(today));

    // Nhóm chưa qua ngày kết thúc trước nhóm đã qua ngày kết thúc
    if (!aIsOver && bIsOver) return -1;
    if (aIsOver && !bIsOver) return 1;

    if (!aIsOver && !bIsOver) {
      // 1. Nhóm chưa qua ngày kết thúc: ngày bắt đầu tăng dần
      final cmp = aStart.compareTo(bStart);
      if (cmp != 0) return cmp;
    } else {
      // 2. Nhóm đã qua ngày kết thúc: ngày bắt đầu giảm dần
      final cmp = bStart.compareTo(aStart);
      if (cmp != 0) return cmp;
    }

    // 4. Cùng nhóm/cùng ngày: dùng id làm tie-breaker ổn định
    return a.id.compareTo(b.id);
  }

  Future<void> fetchEvents() async {
    if (_disposed) return;
    final generation = ++_generation;
    _pending.clear();
    _currentGenPendingRequests = 0;

    if (_allEvents.isEmpty) {
      isInitialLoading = true;
      isRefreshing = false;
      error = null;
    } else {
      isInitialLoading = false;
      isRefreshing = true;
      refreshError = null;
    }
    _notify();

    try {
      final items = await _getEventsUseCase.execute();
      if (_disposed || generation != _generation) return;
      _allEvents = List.of(items);
      _allEvents.sort((a, b) => compareEvents(a, b, _clock().toLocal()));

      if (!locationOptions.contains(selectedLocation)) {
        selectedLocation = locationOptions.first;
      }
      if (!timeOptions.contains(selectedTime)) selectedTime = timeOptions.first;

      for (final event in _allEvents) {
        final state = event.lifecycle.stateAt(_clock());
        if (state != EventRegistrationState.ended &&
            state != EventRegistrationState.cancelled) {
          _pending.add((generation, event));
        }
      }
      _currentGenPendingRequests = _pending.length;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      if (_allEvents.isEmpty) {
        error = e.toString();
      } else {
        refreshError = e.toString();
      }
    } finally {
      if (!_disposed && generation == _generation) {
        isInitialLoading = false;
        isRefreshing = false;
        _applyFilters();
        _pumpDetails();
      }
    }
  }

  void _pumpDetails() {
    while (!_disposed && _activeRequests < 4 && _pending.isNotEmpty) {
      final (generation, event) = _pending.removeFirst();
      _activeRequests++;
      unawaited(_resolveLifecycle(generation, event));
    }
  }

  Future<void> _resolveLifecycle(int generation, EventEntity event) async {
    EventLifecycle lifecycle;
    try {
      lifecycle = await _getEventsUseCase.lifecycle(event.id);
    } catch (_) {
      lifecycle = EventLifecycle(
        status: event.status,
        date: event.date,
        endDate: event.endDate,
        loadState: LifecycleLoadState.failed,
      );
    }
    _activeRequests--;
    if (!_disposed && generation == _generation) {
      _currentGenPendingRequests = (_currentGenPendingRequests - 1).clamp(
        0,
        9999,
      );
      final index = _allEvents.indexWhere((e) => e.id == event.id);
      if (index >= 0) {
        _allEvents[index] = event.withLifecycle(lifecycle);
        _allEvents.sort((a, b) => compareEvents(a, b, _clock().toLocal()));
        _applyFilters();
      }
    }
    _pumpDetails();
  }

  void setPage(int page) {
    if (page < 1 || (pageCount > 0 && page > pageCount)) return;
    if (currentPage == page) return;
    currentPage = page;
    _notify();
  }

  void setSearchQuery(String s) {
    if (searchQuery == s) return;
    searchQuery = s;
    currentPage = 1;
    _applyFilters();
  }

  void applyFilters(HomeFilterSelection selection) {
    final changed =
        selectedDistance != selection.distance ||
        selectedLocation != selection.location ||
        selectedTime != selection.time ||
        selectedStatus != selection.status;
    if (!changed) return;
    selectedDistance = selection.distance;
    selectedLocation = selection.location;
    selectedTime = selection.time;
    selectedStatus = selection.status;
    currentPage = 1;
    _applyFilters();
  }

  void clearFilter(HomeFilterField field) {
    switch (field) {
      case HomeFilterField.distance:
        selectedDistance = distanceOptions.first;
        break;
      case HomeFilterField.location:
        selectedLocation = locationOptions.first;
        break;
      case HomeFilterField.time:
        selectedTime = timeOptions.first;
        break;
      case HomeFilterField.status:
        selectedStatus = statusOptions.first;
        break;
    }
    currentPage = 1;
    _applyFilters();
  }

  void clearFilters() {
    selectedDistance = distanceOptions.first;
    selectedLocation = locationOptions.first;
    selectedTime = timeOptions.first;
    selectedStatus = statusOptions.first;
    currentPage = 1;
    _applyFilters();
  }

  void resetFilters() {
    searchQuery = '';
    selectedDistance = distanceOptions.first;
    selectedLocation = locationOptions.first;
    selectedTime = timeOptions.first;
    selectedStatus = statusOptions.first;
    currentPage = 1;
    _applyFilters();
  }

  void setDistance(String s) {
    if (selectedDistance == s) return;
    selectedDistance = s;
    currentPage = 1;
    _applyFilters();
  }

  void setLocation(String s) {
    if (selectedLocation == s) return;
    selectedLocation = s;
    currentPage = 1;
    _applyFilters();
  }

  void setTime(String s) {
    if (selectedTime == s) return;
    selectedTime = s;
    currentPage = 1;
    _applyFilters();
  }

  void setStatus(String s) {
    if (selectedStatus == s) return;
    selectedStatus = s;
    currentPage = 1;
    _applyFilters();
  }

  void _applyFilters() {
    final now = _clock().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final query = searchQuery.trim().toLowerCase();
    filteredEvents = _allEvents.where((e) {
      if (query.isNotEmpty &&
          !'${e.name} ${e.location} ${e.tagline ?? ''}'.toLowerCase().contains(
            query,
          )) {
        return false;
      }
      if (selectedLocation != locationOptions.first &&
          e.location != selectedLocation) {
        return false;
      }
      if (selectedDistance != distanceOptions.first) {
        final km = double.tryParse(selectedDistance.replaceAll('km', ''));
        if (km != null && !e.distanceKms.any((d) => (d - km).abs() < 1)) {
          return false;
        }
        if (km == null &&
            !e.distanceKms.any(
              (d) => ![5, 10, 21, 42].any((k) => (d - k).abs() < 1),
            )) {
          return false;
        }
      }
      final start = DateTime.tryParse(e.date);
      final end = DateTime.tryParse(e.endDate ?? e.date);
      if (selectedTime == 'Sắp diễn ra' &&
          (end == null || end.isBefore(today) || e.status == 'completed')) {
        return false;
      }
      if (selectedTime == 'Tháng này') {
        if (start == null ||
            end == null ||
            start.isAfter(DateTime(now.year, now.month + 1, 0)) ||
            end.isBefore(DateTime(now.year, now.month))) {
          return false;
        }
      }
      if (selectedTime.startsWith('Năm ') &&
          start?.year.toString() != selectedTime.substring(4)) {
        return false;
      }
      final state = e.lifecycle.stateAt(now);
      final status = state.label;
      if (selectedStatus == 'Đang mở đăng ký' && status != selectedStatus) {
        return false;
      }
      if (selectedStatus == 'Sắp mở đăng ký' &&
          !['Sắp mở đăng ký', 'Chưa đến giờ đăng ký'].contains(status)) {
        return false;
      }
      if (selectedStatus == 'Đã đóng đăng ký' &&
          !['Đã đóng đăng ký', 'Đã hết hạn đăng ký'].contains(status)) {
        return false;
      }
      if (selectedStatus == 'Đã kết thúc' &&
          state != EventRegistrationState.ended) {
        return false;
      }
      return true;
    }).toList();

    // Clamp currentPage when filtered items count changes
    if (pageCount == 0) {
      currentPage = 1;
    } else if (currentPage > pageCount) {
      currentPage = pageCount;
    }

    _notify();
    _scheduleBoundary();
  }
}
