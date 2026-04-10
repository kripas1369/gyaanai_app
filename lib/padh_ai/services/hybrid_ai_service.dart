import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/services/app_settings_service.dart';
import 'gemma_offline_service.dart';
import 'padh_ai_system_prompt.dart';

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

  static const _connectivityCacheDuration = Duration(seconds: 30);
  static const _healthCheckTimeout = Duration(milliseconds: 900);
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
    if (online) return AiMode.online;

    if (gemmaService.isReady) return AiMode.offline;

    final modelPath = await ModelManager.findModel();
    if (modelPath != null) return AiMode.offline;

    return AiMode.unavailable;
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
  }) async {
    String? last;
    await for (final acc in runInferenceStreaming(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      preferOffline: preferOffline,
    )) {
      last = acc;
    }
    return last ?? '';
  }

  /// Stream inference — yields accumulated response as tokens arrive.
  Stream<String> runInferenceStreaming({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    bool preferOffline = false,
  }) async* {
    final mode = await getCurrentMode();

    if (mode == AiMode.unavailable) {
      yield 'No AI available. Please connect to internet or download the offline model.';
      return;
    }

    final useOffline = preferOffline && gemmaService.isReady || mode == AiMode.offline;

    if (useOffline || mode == AiMode.offline) {
      if (!gemmaService.isReady) {
        final initialized = await gemmaService.initialize();
        if (!initialized) {
          yield 'Failed to load offline model. Please try again.';
          return;
        }
      }
      yield* gemmaService.runInferenceAccumulating(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    } else {
      yield* _runOnlineInference(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    }
  }

  /// Online inference via Django → Ollama SSE streaming.
  Stream<String> _runOnlineInference({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
  }) async* {
    final system = systemPrompt ??
        buildPadhAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);

    final uri = Uri.parse('$_baseUrl/api/ai/chat/stream/');

    try {
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';

      final token = settings.accessToken;
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.body = jsonEncode({
        'grade': grade,
        'subject': subjectEnglish,
        'message': userMessage,
        'system_prompt': system,
      });

      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 60),
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        yield 'Server error: ${streamedResponse.statusCode}. $body';
        client.close();
        return;
      }

      var accumulated = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            try {
              final data = jsonDecode(line.substring(6));
              if (data is Map && data['token'] != null) {
                accumulated += data['token'] as String;
                yield accumulated;
              } else if (data is Map && data['done'] == true) {
                break;
              }
            } catch (_) {
              // Skip malformed JSON
            }
          }
        }
      }

      client.close();
    } catch (e) {
      debugPrint('HybridAiService: Online inference error: $e');

      // Fallback to offline if available
      if (gemmaService.isReady || await ModelManager.findModel() != null) {
        debugPrint('HybridAiService: Falling back to offline mode');
        yield* gemmaService.runInferenceAccumulating(
          grade: grade,
          subjectEnglish: subjectEnglish,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
        );
      } else {
        yield 'Connection error: $e';
      }
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
}
