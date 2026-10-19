import '../entities/event_entity.dart';
import '../../../../core/domain/event_lifecycle.dart';

abstract class EventRepository {
  Future<List<EventEntity>> getEvents();
  Future<EventLifecycle> getLifecycle(String id);
}
