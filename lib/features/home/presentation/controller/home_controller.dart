import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../../../../core/domain/event_lifecycle.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/usecases/get_events_usecase.dart';
import '../../data/repositories/event_repository_impl.dart';

class HomeController extends ChangeNotifier {
  final GetEventsUseCase _getEventsUseCase;
  final DateTime Function() _clock;
  bool _disposed = false;
  bool _active = true;
  int _generation = 0, _activeRequests = 0;
  final _pending = Queue<(int, EventEntity)>();
  Timer? _boundaryTimer;
  List<EventEntity> _allEvents = [];
  List<EventEntity> get allEvents => _allEvents;
  List<EventEntity> filteredEvents = [];
  List<EventEntity> get bannerEvents => filteredEvents.take(3).toList();
  String statusFor(EventEntity event) =>
      event.lifecycle.stateAt(_clock()).label;
  bool isLoading = true;
  String? error;
  String searchQuery = '';
  String selectedDistance = 'Tất cả cự ly';
  String selectedLocation = 'Tất cả địa điểm';
  String selectedTime = 'Tất cả thời gian';
  String selectedStatus = 'Tất cả trạng thái';
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
    // A detail refresh can move the last race out of the selected year.
    // Keep that selection valid and show an empty result rather than resetting it.
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

  Future<void> fetchEvents() async {
    if (_disposed) return;
    final generation = ++_generation;
    _pending.clear();
    isLoading = true;
    error = null;
    _notify();
    try {
      final items = await _getEventsUseCase.execute();
      if (_disposed || generation != _generation) return;
      _allEvents = List.of(items);
      _allEvents.sort((a, b) => a.date.compareTo(b.date));
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
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        _applyFilters();
        _pumpDetails();
      }
    }
  }

  void _pumpDetails() {
    // Count in-flight requests across refresh generations as well.
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
      final index = _allEvents.indexWhere((e) => e.id == event.id);
      if (index >= 0) {
        _allEvents[index] = event.withLifecycle(lifecycle);
        _allEvents.sort((a, b) => a.date.compareTo(b.date));
        _applyFilters();
      }
    }
    _pumpDetails();
  }

  void setSearchQuery(String s) {
    searchQuery = s;
    _applyFilters();
  }

  void setDistance(String s) {
    selectedDistance = s;
    _applyFilters();
  }

  void setLocation(String s) {
    selectedLocation = s;
    _applyFilters();
  }

  void setTime(String s) {
    selectedTime = s;
    _applyFilters();
  }

  void setStatus(String s) {
    selectedStatus = s;
    _applyFilters();
  }

  void resetFilters() {
    searchQuery = '';
    selectedDistance = distanceOptions.first;
    selectedLocation = locationOptions.first;
    selectedTime = timeOptions.first;
    selectedStatus = statusOptions.first;
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
    _notify();
    _scheduleBoundary();
  }
}
