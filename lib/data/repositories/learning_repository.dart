import '../providers/remote_data_provider.dart';
import '../services/local_db_service.dart';

class LearningRepository {
  LearningRepository(this.remote, this.local);

  final RemoteDataProvider remote;
  final LocalDbService local;
}
