import 'package:flutter/material.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/usecases/get_events_usecase.dart';
import '../../data/repositories/event_repository_impl.dart';

class HomeController extends ChangeNotifier {
  final GetEventsUseCase _getEventsUseCase;

  List<EventEntity> _allEvents = [];
  List<EventEntity> _filteredEvents = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedDistance = '- Cự ly -';
  String _selectedLocation = '- Địa điểm -';
  String _selectedTime = '- Thời gian -';

  List<EventEntity> get allEvents => _allEvents;
  List<EventEntity> get filteredEvents => _filteredEvents;
  List<EventEntity> get bannerEvents => _allEvents.take(3).toList();
  bool get isLoading => _isLoading;

  String get selectedDistance => _selectedDistance;
  String get selectedLocation => _selectedLocation;
  String get selectedTime => _selectedTime;

  final List<String> distanceOptions = const [
    '- Cự ly -',
    'Tất cả',
    '5km',
    '10km',
    '21km',
    '42km',
  ];

  final List<String> locationOptions = const [
    '- Địa điểm -',
    'Tất cả',
    'Hạ Long',
    'Nha Trang',
    'Đà Nẵng',
    'Hà Nội',
    'TP. Hồ Chí Minh',
  ];

  final List<String> timeOptions = const [
    '- Thời gian -',
    'Tất cả',
    'Sắp diễn ra',
    'Tháng này',
    'Năm 2026',
    'Năm 2027',
  ];

  HomeController({GetEventsUseCase? getEventsUseCase})
      : _getEventsUseCase = getEventsUseCase ?? GetEventsUseCase(EventRepositoryImpl());

  Future<void> fetchEvents() async {
    _isLoading = true;
    notifyListeners();

    _allEvents = await _getEventsUseCase.execute();
    _isLoading = false;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setDistance(String val) {
    _selectedDistance = val;
    _applyFilters();
  }

  void setLocation(String val) {
    _selectedLocation = val;
    _applyFilters();
  }

  void setTime(String val) {
    _selectedTime = val;
    _applyFilters();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedDistance = '- Cự ly -';
    _selectedLocation = '- Địa điểm -';
    _selectedTime = '- Thời gian -';
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();

    _filteredEvents = _allEvents.where((e) {
      // 1. Search Query
      final matchesQuery = query.isEmpty ||
          e.name.toLowerCase().contains(query) ||
          e.location.toLowerCase().contains(query) ||
          (e.tagline ?? '').toLowerCase().contains(query);

      // 2. Distance
      bool matchesDistance = true;
      if (_selectedDistance != '- Cự ly -' && _selectedDistance != 'Tất cả') {
        final targetKm = double.tryParse(_selectedDistance.replaceAll('km', ''));
        matchesDistance = e.distances.any((d) {
          if (targetKm != null) {
            return (d.distanceKm - targetKm).abs() < 1.0 ||
                d.name.toLowerCase().contains(_selectedDistance.toLowerCase());
          }
          return d.name.toLowerCase().contains(_selectedDistance.toLowerCase());
        });
      }

      // 3. Location
      bool matchesLocation = true;
      if (_selectedLocation != '- Địa điểm -' && _selectedLocation != 'Tất cả') {
        matchesLocation = e.location.toLowerCase().contains(_selectedLocation.toLowerCase());
      }

      // 4. Time
      bool matchesTime = true;
      if (_selectedTime != '- Thời gian -' && _selectedTime != 'Tất cả') {
        if (_selectedTime == 'Năm 2026') {
          matchesTime = e.date.contains('2026');
        } else if (_selectedTime == 'Năm 2027') {
          matchesTime = e.date.contains('2027');
        } else if (_selectedTime == 'Sắp diễn ra') {
          matchesTime = e.status.toLowerCase().contains('open') ||
              e.status.toLowerCase().contains('approved');
        }
      }

      return matchesQuery && matchesDistance && matchesLocation && matchesTime;
    }).toList();

    notifyListeners();
  }
}
