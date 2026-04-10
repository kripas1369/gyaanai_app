import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/api_service.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/local_db_service.dart';
import '../services/gemma_offline_service.dart';
import '../services/hybrid_ai_service.dart';
import '../services/model_loader_service.dart';
import '../services/offline_task_sync_service.dart';
import '../services/padh_ai_chat_repository.dart';

/// Injected in [main] via [ProviderScope.overrides].
final localDbProvider = Provider<LocalDbService>((ref) {
  throw UnimplementedError('localDbProvider must be overridden in ProviderScope');
});

final appSettingsProvider = Provider<AppSettingsService>((ref) {
  throw UnimplementedError('appSettingsProvider must be overridden in ProviderScope');
});

/// Django REST client (JWT from [AppSettingsService]).
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(appSettingsProvider));
});

/// SharedPreferences provider - injected in main.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPrefsProvider must be overridden');
});

/// Model loader for downloading/managing the Gemma model file.
/// The loader handles Android localhost rewrite internally.
final modelLoaderProvider = Provider<ModelLoaderService>((ref) {
  final loader = ModelLoaderService(ref.watch(sharedPrefsProvider));
  // Set Django URL for model download (loader handles Android localhost rewrite)
  final settings = ref.watch(appSettingsProvider);
  loader.setDjangoBaseUrl(settings.djangoBaseUrl);
  return loader;
});

/// Gemma offline inference service.
final gemmaOfflineProvider = Provider<GemmaOfflineService>((ref) {
  final s = GemmaOfflineService();
  ref.onDispose(s.dispose);
  return s;
});

/// Hybrid AI service - automatically switches between online/offline
final hybridAiProvider = Provider<HybridAiService>((ref) {
  return HybridAiService(
    settings: ref.watch(appSettingsProvider),
    gemmaService: ref.watch(gemmaOfflineProvider),
  );
});

/// Offline task sync service - queues tasks when offline, syncs when online
final offlineSyncProvider = Provider<OfflineTaskSyncService>((ref) {
  final service = OfflineTaskSyncService(
    db: ref.watch(localDbProvider),
    settings: ref.watch(appSettingsProvider),
  );
  // Start periodic sync
  service.startPeriodicSync();
  ref.onDispose(service.dispose);
  return service;
});

/// Current AI mode (online, offline, or unavailable)
final aiModeProvider = FutureProvider<AiMode>((ref) async {
  final hybrid = ref.watch(hybridAiProvider);
  return hybrid.getCurrentMode();
});

/// Stream of Gemma model status for UI updates.
final gemmaStatusProvider = StreamProvider<GemmaModelStatus>((ref) {
  final gemma = ref.watch(gemmaOfflineProvider);
  return gemma.statusStream;
});

final padhChatRepoProvider = Provider<PadhAiChatRepository>(
  (ref) => PadhAiChatRepository(ref.watch(localDbProvider)),
);

enum PadhConnectivityLabel { online, offlineLocal }

final padhConnectivityProvider =
    StreamProvider<PadhConnectivityLabel>((ref) async* {
  final connectivity = Connectivity();
  final hybrid = ref.watch(hybridAiProvider);

  Future<PadhConnectivityLabel> read() async {
    final list = await connectivity.checkConnectivity();
    final has = list.any((r) => r != ConnectivityResult.none);
    if (!has) return PadhConnectivityLabel.offlineLocal;

    // Network is present; "online" means Django is actually reachable.
    final ok = await hybrid.refreshConnectivity();
    return ok == AiMode.online
        ? PadhConnectivityLabel.online
        : PadhConnectivityLabel.offlineLocal;
  }

  yield await read();
  await for (final _ in connectivity.onConnectivityChanged) {
    yield await read();
  }
});
