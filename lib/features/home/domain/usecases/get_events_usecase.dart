import '../entities/event_entity.dart';
import '../../../../core/domain/event_lifecycle.dart';
import '../repositories/event_repository.dart';

class GetEventsUseCase {
  final EventRepository repository;

  GetEventsUseCase(this.repository);

  Future<EventLifecycle> lifecycle(String id) => repository.getLifecycle(id);

  Future<List<EventEntity>> execute() {
    return repository.getEvents();
  }
}
