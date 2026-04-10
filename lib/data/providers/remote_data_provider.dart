import '../services/api_service.dart';

/// Fetches remote entities; keeps API shape out of repositories.
class RemoteDataProvider {
  RemoteDataProvider(this.api);

  final ApiService api;
}
