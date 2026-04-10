import '../services/local_db_service.dart';

/// Reads/writes cached rows via [LocalDbService].
class LocalDataProvider {
  LocalDataProvider(this.db);

  final LocalDbService db;
}
