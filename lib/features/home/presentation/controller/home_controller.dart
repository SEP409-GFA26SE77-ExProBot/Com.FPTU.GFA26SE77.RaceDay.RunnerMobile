import 'package:flutter/material.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/usecases/get_events_usecase.dart';
import '../../data/repositories/event_repository_impl.dart';

class HomeController extends ChangeNotifier {
  final GetEventsUseCase _getEventsUseCase;
  final DateTime Function() _clock;
  bool _disposed = false;
  List<EventEntity> _allEvents = [];
  List<EventEntity> get allEvents => _allEvents;
  List<EventEntity> filteredEvents = [];
  List<EventEntity> get bannerEvents => filteredEvents.take(3).toList();
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
    super.dispose();
  }

  Future<void> fetchEvents() async {
    isLoading = true;
    error = null;
    _notify();
    try {
      _allEvents = await _getEventsUseCase.execute();
      _allEvents.sort((a, b) => a.date.compareTo(b.date));
      if (!locationOptions.contains(selectedLocation)) {
        selectedLocation = locationOptions.first;
      }
      if (!timeOptions.contains(selectedTime)) selectedTime = timeOptions.first;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      _applyFilters();
    }
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
    final now = _clock();
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
      final status = e.statusDisplay;
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
      if (selectedStatus == 'Đã kết thúc' && e.status != 'completed') {
        return false;
      }
      return true;
    }).toList();
    _notify();
  }
}
