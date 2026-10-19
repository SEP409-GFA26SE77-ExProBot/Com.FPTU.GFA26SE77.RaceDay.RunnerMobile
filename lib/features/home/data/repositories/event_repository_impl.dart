import '../../domain/entities/event_entity.dart';
import '../../../../core/domain/event_lifecycle.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_remote_data_source.dart';

class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource remoteDataSource;

  EventRepositoryImpl({EventRemoteDataSource? remote})
    : remoteDataSource = remote ?? EventRemoteDataSourceImpl();

  @override
  Future<EventLifecycle> getLifecycle(String id) =>
      remoteDataSource.getLifecycle(id);

  @override
  Future<List<EventEntity>> getEvents() {
    return remoteDataSource.getEvents();
  }
}
