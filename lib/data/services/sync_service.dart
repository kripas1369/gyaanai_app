import 'api_service.dart';
import 'app_settings_service.dart';
import 'connectivity_mode_service.dart';
import 'local_db_service.dart';

/// Pulls curriculum from Django when online; stores SQLite rows for offline.
/// Progress push to Django can enqueue rows here later.
class SyncService {
  SyncService(this._settings, this._api, this._local, this._connectivity);

  final AppSettingsService _settings;
  final ApiService _api;
  final LocalDbService _local;
  final ConnectivityModeService _connectivity;

  /// Fetches subjects → topics (for [grade]) → lesson lists when Django is reachable.
  Future<void> syncCurriculum() async {
    final mode = await _connectivity.detectMode();
    if (mode != AppConnectivityMode.online) return;

    final grade = _settings.localGrade;
    final subjects = await _api.getSubjects();
    await _local.upsertSubjects(subjects);

    for (final s in subjects) {
      final sid = s['id'] as int;
      final topics = await _api.getTopicsForSubject(sid, grade: grade);
      await _local.upsertTopics(sid, topics);
      for (final t in topics) {
        final tid = t['id'] as int;
        final lessons = await _api.getLessonsForTopic(tid);
        await _local.upsertLessonList(tid, lessons);
      }
    }
  }

  /// Loads full lesson JSON (markdown content) from API and caches it.
  Future<Map<String, dynamic>> ensureLessonDetail(int lessonId) async {
    final cached = await _local.getLessonDetail(lessonId);
    if (cached != null) return cached;

    final mode = await _connectivity.detectMode();
    if (mode != AppConnectivityMode.online) {
      throw StateError(
        'Lesson not downloaded. Connect to the internet (Django) once to cache lessons.',
      );
    }

    final detail = await _api.getLessonDetail(lessonId);
    await _local.upsertLessonDetail(detail);
    return detail;
  }
}
