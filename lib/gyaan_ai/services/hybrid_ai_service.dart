import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/services/app_settings_service.dart';
import 'gemma_offline_service.dart';
import 'gyaan_ai_system_prompt.dart';

// Re-export ChatHistoryMessage for use in chat screen
export 'gemma_offline_service.dart' show ChatHistoryMessage;

/// AI inference mode
enum AiMode {
  online,      // Use Django API (Ollama on server)
  offline,     // Use local Gemma model
  unavailable, // No model downloaded & no internet
}

/// Result of AI inference with metadata
class AiInferenceResult {
  final String response;
  final AiMode usedMode;
  final int? tokensUsed;
  final Duration? latency;

  AiInferenceResult({
    required this.response,
    required this.usedMode,
    this.tokensUsed,
    this.latency,
  });
}

/// Hybrid AI Service that automatically switches between:
/// - Online: Django API → Ollama (faster, saves battery, no model needed)
/// - Offline: Local Gemma model (works without internet)
class HybridAiService {
  HybridAiService({
    required this.settings,
    required this.gemmaService,
  });

  final AppSettingsService settings;
  final GemmaOfflineService gemmaService;

  bool _isOnline = false;
  DateTime? _lastConnectivityCheck;
  /// After a fast connection failure, skip hammering an unreachable host.
  DateTime? _negativeCacheUntil;
  AiMode? _lastMode;

  static const _connectivityCacheDuration = Duration(seconds: 30);
  static const _healthCheckTimeout = Duration(milliseconds: 400);
  static const _negativeCacheAfterFailure = Duration(seconds: 90);

  /// The base URL used for all Django HTTP calls (already Android-rewritten).
  String get _baseUrl => settings.effectiveDjangoBaseUrl;

  /// Current AI mode based on connectivity and model availability.
  ///
  /// Backend contract (gyaanai_backend):
  ///   GET /api/health/       → Django reachable (always 200 if server runs)
  ///   GET /api/ai/health/    → AI ready (200 only when Ollama is up + model pulled)
  ///   POST /api/ai/chat/stream/ → online chat (SSE)
  ///   GET /api/ai/model/info/   → offline model metadata
  ///   GET /api/ai/model/download/ → offline model binary
  Future<AiMode> getCurrentMode() async {
    final online = await _checkOnlineStatus();
    if (online) {
      _lastMode = AiMode.online;
      return AiMode.online;
    }

    if (gemmaService.isReady) {
      _lastMode = AiMode.offline;
      return AiMode.offline;
    }

    final modelPath = await ModelManager.findModel();
    if (modelPath != null) {
      _lastMode = AiMode.offline;
      return AiMode.offline;
    }

    _lastMode = AiMode.unavailable;
    return AiMode.unavailable;
  }

  /// Fast mode lookup that avoids waiting on network health checks.
  ///
  /// - If we recently checked connectivity, reuse the cached result.
  /// - If an offline model is already ready, prefer that immediately.
  /// - Otherwise fall back to the last known mode while we attempt inference.
  Future<AiMode> getCurrentModeFast() async {
    // Offline ready? return instantly.
    if (gemmaService.isReady) {
      _lastMode = AiMode.offline;
      return AiMode.offline;
    }

    // Recently checked connectivity? use cached state.
    final now = DateTime.now();
    if (_lastConnectivityCheck != null &&
        now.difference(_lastConnectivityCheck!) < _connectivityCacheDuration) {
      final mode = _isOnline ? AiMode.online : (_lastMode ?? AiMode.offline);
      _lastMode = mode;
      return mode;
    }

    return _lastMode ?? AiMode.offline;
  }

  /// Check if Django + Ollama AI is reachable (`/api/ai/health/` returns 200).
  Future<bool> _checkOnlineStatus() async {
    final now = DateTime.now();
    if (_negativeCacheUntil != null && now.isBefore(_negativeCacheUntil!)) {
      return false;
    }

    if (_lastConnectivityCheck != null) {
      final elapsed = now.difference(_lastConnectivityCheck!);
      if (elapsed < _connectivityCacheDuration) return _isOnline;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/ai/health/');
      final response = await http.get(uri).timeout(
        _healthCheckTimeout,
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _negativeCacheUntil = null;
        // Double-check the body: Ollama may be reachable but the
        // configured model might not be pulled yet.
        try {
          final body = jsonDecode(response.body);
          _isOnline = body is Map && body['model_available'] == true;
        } catch (_) {
          _isOnline = true;
        }
      } else {
        _isOnline = false;
      }
    } catch (e) {
      debugPrint('HybridAiService: Online check failed: $e');
      _isOnline = false;
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused') ||
          msg.contains('Failed host lookup')) {
        _negativeCacheUntil =
            DateTime.now().add(_negativeCacheAfterFailure);
      }
    }

    _lastConnectivityCheck = DateTime.now();
    return _isOnline;
  }

  /// Force refresh connectivity status.
  Future<AiMode> refreshConnectivity() async {
    _lastConnectivityCheck = null;
    _negativeCacheUntil = null;
    return getCurrentMode();
  }

  /// Run inference — automatically chooses online or offline.
  Future<String> runInference({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    bool preferOffline = false,
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async {
    String? last;
    await for (final acc in runInferenceStreaming(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      preferOffline: preferOffline,
      sessionId: sessionId,
      history: history,
    )) {
      last = acc;
    }
    return last ?? '';
  }

  /// Stream inference — yields accumulated response as tokens arrive.
  /// Now supports session tracking and conversation history for context-aware responses.
  Stream<String> runInferenceStreaming({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    bool preferOffline = false,
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async* {
    final now = DateTime.now();

    // If user asked to prefer offline, do it deterministically.
    if (preferOffline) {
      yield* _runOfflineInference(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        sessionId: sessionId,
        history: history,
      );
      return;
    }

    // If we recently observed hard network failure, skip online attempts briefly.
    if (_negativeCacheUntil != null && now.isBefore(_negativeCacheUntil!)) {
      yield* _runOfflineOrUnavailable(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        sessionId: sessionId,
        history: history,
      );
      return;
    }

    // SPEED OPTIMIZATION: If offline model is already loaded, use it immediately
    // to skip network latency entirely. This makes responses much faster.
    if (gemmaService.isReady) {
      yield* _runOfflineInference(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        sessionId: sessionId,
        history: history,
      );
      return;
    }

    // Optimistic online-first: avoids waiting on `/api/ai/health/` per message.
    // If online fails quickly, we transparently fall back to offline.
    var producedAnyToken = false;
    try {
      await for (final acc in _runOnlineInference(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
      )) {
        producedAnyToken = true;
        yield acc;
      }
      _lastMode = AiMode.online;
    } catch (e) {
      debugPrint('HybridAiService: Online stream failed, falling back: $e');
      // If we got nothing from online, fall back immediately.
      if (!producedAnyToken) {
        yield* _runOfflineOrUnavailable(
          grade: grade,
          subjectEnglish: subjectEnglish,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          sessionId: sessionId,
          history: history,
        );
      } else {
        // If we already streamed part of an answer, don't switch mid-message.
        yield '\n\n(Connectivity issue while streaming. Please try again.)';
      }
    } finally {
      // Opportunistically refresh mode in the background for the next request.
      // (Do not await — keeps current request snappy.)
      unawaited(getCurrentMode());
    }
  }

  Stream<String> _runOfflineInference({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async* {
    if (!gemmaService.isReady) {
      final initialized = await gemmaService.initialize();
      if (!initialized) {
        yield 'Failed to load offline model. Please try again.';
        return;
      }
    }
    _lastMode = AiMode.offline;
    yield* gemmaService.runInferenceAccumulating(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      sessionId: sessionId,
      history: history,
    );
  }

  Stream<String> _runOfflineOrUnavailable({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async* {
    if (gemmaService.isReady || await ModelManager.findModel() != null) {
      yield* _runOfflineInference(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        sessionId: sessionId,
        history: history,
      );
      return;
    }
    _lastMode = AiMode.unavailable;
    yield 'No AI available. Please connect to internet or download the offline model.';
  }

  /// Online inference via Django → Ollama SSE streaming.
  /// Now includes conversation history for context-aware responses.
  Stream<String> _runOnlineInference({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    List<ChatHistoryMessage>? history,
  }) async* {
    final system = systemPrompt ??
        buildGyaanAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);

    final uri = Uri.parse('$_baseUrl/api/ai/chat/stream/');

    http.Client? client;
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream';

      final token = settings.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Build history for Django/Ollama (same format as ChatGPT API)
      final historyJson = history?.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      request.body = jsonEncode({
        'grade': grade,
        'subject': subjectEnglish,
        'message': userMessage,
        'system_prompt': system,
        if (historyJson != null && historyJson.isNotEmpty) 'history': historyJson,
      });

      client = http.Client();
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 60),
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        // Treat as a connection failure so callers can fall back quickly.
        _negativeCacheUntil = DateTime.now().add(_negativeCacheAfterFailure);
        throw StateError('Server error: ${streamedResponse.statusCode}. $body');
      }

      // Parse SSE robustly: "data: ..." lines can be split across TCP chunks.
      var accumulated = '';
      var buffer = '';
      var done = false;

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        if (done) break;
        buffer += chunk;

        while (true) {
          final nl = buffer.indexOf('\n');
          if (nl == -1) break;
          var line = buffer.substring(0, nl);
          buffer = buffer.substring(nl + 1);

          if (line.endsWith('\r')) {
            line = line.substring(0, line.length - 1);
          }
          if (!line.startsWith('data:')) continue;

          final payload = line.length >= 6 ? line.substring(5).trimLeft() : '';
          if (payload.isEmpty) continue;

          try {
            final data = jsonDecode(payload);
            if (data is Map && data['token'] != null) {
              _negativeCacheUntil = null;
              _isOnline = true;
              _lastConnectivityCheck = DateTime.now();
              accumulated += data['token'] as String;
              yield accumulated;
            } else if (data is Map && data['done'] == true) {
              done = true;
              break;
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }
    } catch (e) {
      debugPrint('HybridAiService: Online inference error: $e');

      // Mark online as likely down; callers may choose to fall back.
      _isOnline = false;
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Connection refused') ||
          msg.contains('Failed host lookup') ||
          msg.contains('timeout')) {
        _negativeCacheUntil = DateTime.now().add(_negativeCacheAfterFailure);
      }
      rethrow;
    } finally {
      client?.close();
    }
  }

  /// Check if offline model is available.
  Future<bool> isOfflineModelAvailable() async {
    if (gemmaService.isReady) return true;
    final path = await ModelManager.findModel();
    return path != null;
  }

  /// Get model info from Django including download URL.
  Future<Map<String, dynamic>?> getModelInfo() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/ai/model/info/');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('HybridAiService: Failed to get model info: $e');
    }
    return null;
  }

  /// Get model download URL from Django.
  Future<String?> getModelDownloadUrl() async {
    final info = await getModelInfo();
    return info?['download_url'] as String?;
  }

  /// Release offline model for memory pressure situations.
  /// Call this when the app receives low memory warnings.
  Future<void> releaseForMemoryPressure() async {
    await gemmaService.releaseForMemoryPressure();
  }

  /// Clear conversation session (e.g., when starting new chat).
  void clearSession(int sessionId) {
    gemmaService.clearSession(sessionId);
  }

  /// Clear all conversation sessions.
  void clearAllSessions() {
    gemmaService.clearAllSessions();
  }
}
