import '../entities/event_entity.dart';
import '../repositories/event_repository.dart';

class GetEventsUseCase {
  final EventRepository repository;

  GetEventsUseCase(this.repository);

  Future<List<EventEntity>> execute() {
    return repository.getEvents();
  }
}
