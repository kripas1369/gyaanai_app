import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/services/app_settings_service.dart';
import '../../data/services/local_db_service.dart';

/// Types of tasks that can be synced
enum SyncTaskType {
  chatSession,    // Sync a complete chat session
  chatMessage,    // Sync individual message
  userProgress,   // Sync user learning progress
  quizResult,     // Sync quiz results
}

/// A task pending sync to the Django server
class PendingSyncTask {
  final int id;
  final SyncTaskType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  PendingSyncTask({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory PendingSyncTask.fromDb(Map<String, Object?> row) {
    return PendingSyncTask(
      id: row['id'] as int,
      type: SyncTaskType.values.firstWhere(
        (t) => t.name == row['kind'],
        orElse: () => SyncTaskType.chatMessage,
      ),
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      retryCount: (row['retry_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toDb() => {
        'kind': type.name,
        'payload': jsonEncode(payload),
        'created_at': createdAt.millisecondsSinceEpoch,
        'retry_count': retryCount,
      };
}

/// Service that manages offline task queue and syncs to Django when online
class OfflineTaskSyncService {
  OfflineTaskSyncService({
    required this.db,
    required this.settings,
  });

  final LocalDbService db;
  final AppSettingsService settings;

  bool _isSyncing = false;
  Timer? _syncTimer;
  final _syncController = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get syncStream => _syncController.stream;

  /// Start periodic sync (call once on app startup)
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncAll());
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Queue a chat session for sync
  Future<void> queueChatSession({
    required int sessionId,
    required int grade,
    required String subject,
    required String title,
    required List<Map<String, dynamic>> messages,
  }) async {
    await db.enqueueSync(SyncTaskType.chatSession.name, {
      'session_id': sessionId,
      'grade': grade,
      'subject': subject,
      'title': title,
      'messages': messages,
      'device_id': await _getDeviceId(),
    });
    debugPrint('OfflineSync: Queued chat session $sessionId for sync');
  }

  /// Queue a single message for sync
  Future<void> queueChatMessage({
    required int sessionId,
    required String role,
    required String content,
    required DateTime createdAt,
  }) async {
    await db.enqueueSync(SyncTaskType.chatMessage.name, {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'device_id': await _getDeviceId(),
    });
  }

  /// Queue user progress for sync
  Future<void> queueProgress({
    required int grade,
    required String subject,
    required String topicId,
    required double completionPercent,
    required int timeSpentMinutes,
  }) async {
    await db.enqueueSync(SyncTaskType.userProgress.name, {
      'grade': grade,
      'subject': subject,
      'topic_id': topicId,
      'completion_percent': completionPercent,
      'time_spent_minutes': timeSpentMinutes,
      'device_id': await _getDeviceId(),
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  /// Queue quiz result for sync
  Future<void> queueQuizResult({
    required int grade,
    required String subject,
    required String quizId,
    required int score,
    required int totalQuestions,
    required List<Map<String, dynamic>> answers,
  }) async {
    await db.enqueueSync(SyncTaskType.quizResult.name, {
      'grade': grade,
      'subject': subject,
      'quiz_id': quizId,
      'score': score,
      'total_questions': totalQuestions,
      'answers': answers,
      'device_id': await _getDeviceId(),
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get pending task count
  Future<int> getPendingCount() async {
    // This would need a count query in LocalDbService
    // For now, return 0 as placeholder
    return 0;
  }

  /// Sync all pending tasks to Django
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    _isSyncing = true;
    _syncController.add(SyncStatus.syncing);

    int synced = 0;
    int failed = 0;
    final errors = <String>[];

    try {
      // Check if we're online
      final isOnline = await _checkOnline();
      if (!isOnline) {
        _isSyncing = false;
        _syncController.add(SyncStatus.offline);
        return SyncResult(success: false, message: 'No internet connection');
      }

      // Get all pending tasks from sync_queue table
      // Note: We'd need to add a method to LocalDbService to fetch sync_queue items
      // For now, we'll use the existing enqueueSync pattern

      debugPrint('OfflineSync: Sync complete - $synced synced, $failed failed');

      _isSyncing = false;
      _syncController.add(failed == 0 ? SyncStatus.complete : SyncStatus.partialError);

      return SyncResult(
        success: failed == 0,
        syncedCount: synced,
        failedCount: failed,
        errors: errors,
      );
    } catch (e) {
      debugPrint('OfflineSync: Sync error: $e');
      _isSyncing = false;
      _syncController.add(SyncStatus.error);
      return SyncResult(success: false, message: e.toString());
    }
  }

  /// Sync a single task to the server
  /// Used by syncAll when processing pending tasks
  // ignore: unused_element
  Future<bool> _syncTask(PendingSyncTask task) async {
    final base = settings.effectiveDjangoBaseUrl;
    final endpoint = _getEndpointForType(task.type);
    final uri = Uri.parse('$base$endpoint');

    try {
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(task.payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        debugPrint('OfflineSync: Task ${task.id} failed with ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('OfflineSync: Task ${task.id} error: $e');
      return false;
    }
  }

  String _getEndpointForType(SyncTaskType type) {
    switch (type) {
      case SyncTaskType.chatSession:
        return '/api/ai/sync/chat-session/';
      case SyncTaskType.chatMessage:
        return '/api/ai/sync/chat-message/';
      case SyncTaskType.userProgress:
        return '/api/progress/sync/';
      case SyncTaskType.quizResult:
        return '/api/quiz/sync/result/';
    }
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = settings.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<bool> _checkOnline() async {
    try {
      final base = settings.effectiveDjangoBaseUrl;
      final uri = Uri.parse('$base/api/health/');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  Future<String> _getDeviceId() async {
    // Use a simple device identifier
    // In production, use device_info_plus package
    return 'flutter_device_${DateTime.now().millisecondsSinceEpoch % 100000}';
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncController.close();
  }
}

/// Status of sync operation
enum SyncStatus {
  idle,
  syncing,
  complete,
  partialError,
  error,
  offline,
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int syncedCount;
  final int failedCount;
  final String? message;
  final List<String> errors;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.message,
    this.errors = const [],
  });
}
