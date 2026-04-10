import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import 'padh_ai_system_prompt.dart';

/// Status of the Gemma model.
enum GemmaModelStatus {
  notFound,
  loading,
  ready,
  error,
}

/// Manages finding the model file on the device.
/// Checks app Documents dir (where ModelLoaderService downloads),
/// app Support dir, and external Downloads folder.
class ModelManager {
  static const String modelFileName = 'gemma-4-E2B-it.litertlm';

  /// Reject tiny/corrupt side-loaded files (LiteRT may error with status 13).
  static const int minSideLoadedModelBytes = 800 * 1024 * 1024;

  /// Same floor as [ModelLoaderService] — app download is only marked complete above this.
  static const int minDownloadedModelBytes = 2000000000;

  static const List<String> _externalPaths = [
    '/sdcard/Download/gemma-4-E2B-it.litertlm',
    '/sdcard/Download/gemma.litertlm',
    '/storage/emulated/0/Download/gemma-4-E2B-it.litertlm',
    '/storage/emulated/0/Download/gemma.litertlm',
  ];

  /// Returns the model path if found, null otherwise.
  static Future<String?> findModel() async {
    // 1. Check app Documents dir (ModelLoaderService downloads here)
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final docsFile = File('${docsDir.path}/models/$modelFileName');
      if (await docsFile.exists()) {
        final len = await docsFile.length();
        if (len >= minDownloadedModelBytes) {
          debugPrint('ModelManager: Found model in Documents');
          return docsFile.path;
        }
        debugPrint('ModelManager: Documents model incomplete ($len bytes), ignoring');
      }
    } catch (e) {
      debugPrint('ModelManager: Error checking Documents: $e');
    }

    // 2. Check app Support dir
    try {
      final dir = await getApplicationSupportDirectory();
      final internal = File('${dir.path}/$modelFileName');
      if (await internal.exists()) {
        final len = await internal.length();
        if (len >= minSideLoadedModelBytes) {
          debugPrint('ModelManager: Found model in app support');
          return internal.path;
        }
        debugPrint('ModelManager: Support dir model too small ($len bytes), ignoring');
      }
    } catch (e) {
      debugPrint('ModelManager: Error checking app support: $e');
    }

    // 3. Check known external paths (user-placed in Downloads)
    for (final path in _externalPaths) {
      try {
        final f = File(path);
        if (await f.exists()) {
          final len = await f.length();
          if (len >= minSideLoadedModelBytes) {
            debugPrint('ModelManager: Found model at $path');
            return path;
          }
          debugPrint('ModelManager: External model too small at $path ($len bytes)');
        }
      } catch (e) {
        debugPrint('ModelManager: Error checking $path: $e');
      }
    }

    debugPrint('ModelManager: Model not found');
    return null;
  }

  /// Returns path for storing a downloaded model in app storage.
  static Future<String> getInternalModelPath() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/$modelFileName';
  }
}

bool _isLiteRtStatus13(Object e) {
  final s = e is PlatformException
      ? '${e.message} ${e.details}'
      : e.toString();
  final lower = s.toLowerCase();
  return lower.contains('status code: 13') || lower.contains('status code 13');
}

String _friendlyOfflineInferenceError(Object e) {
  if (_isLiteRtStatus13(e)) {
    return 'On-device AI failed in LiteRT (error 13). Logs often show '
        'DYNAMIC_UPDATE_SLICE / failed to allocate tensors — usually wrong or too-small '
        'context budget, out of memory, or a bad `.litertlm` file. Try: update the app, '
        're-download the full model, restart the device, or use online mode.';
  }
  return 'Error: $e';
}

String _friendlyEmptyLiteRtOutput() {
  return 'On-device AI returned no text (LiteRT prefill failed). On Android, CPU inference '
      'often uses XNNPACK and can hit a known tensor bug; the app tries GPU first when possible. '
      'Try updating the app, freeing RAM, re-downloading the model, or use online mode.';
}

String _buildOfflineInferencePrompt({
  required int grade,
  required String subjectEnglish,
  required String userMessage,
  String? systemPrompt,
  required int maxChars,
}) {
  var system = systemPrompt ??
      buildPadhAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);
  if (system.length > 1200) {
    system = '${system.substring(0, 1200)}\n…';
  }
  var user = userMessage.trim();
  if (user.length > 2000) {
    user = '${user.substring(0, 2000)}\n…';
  }
  var prompt = '''$system

Student (Class $grade, $subjectEnglish):
$user

Teacher:''';
  if (prompt.length > maxChars) {
    prompt =
        '${prompt.substring(0, maxChars)}\n\n[Prompt shortened for on-device AI]';
  }
  return prompt;
}

/// Android: GPU before CPU. CPU LiteRT often applies [TfLiteXNNPackDelegate], which has
/// triggered `DYNAMIC_UPDATE_SLICE` prepare failures for some Gemma `.litertlm` builds.
List<PreferredBackend> _defaultLiteRtBackendOrder() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return [PreferredBackend.gpu, PreferredBackend.cpu];
  }
  return [PreferredBackend.cpu, PreferredBackend.gpu];
}

List<PreferredBackend> _liteRtBackendsToTry({
  PreferredBackend? lastUsed,
  required bool preferOtherFirst,
}) {
  final defaults = _defaultLiteRtBackendOrder();
  if (!preferOtherFirst || lastUsed == null) return defaults;
  final others = defaults.where((b) => b != lastUsed).toList();
  return [...others, lastUsed];
}

/// Offline Gemma 4 via [flutter_gemma] (LiteRT-LM / MediaPipe).
/// Uses model file from device storage (not bundled in APK).
class GemmaOfflineService {
  /// KV / context budget. Too small breaks prefill; `flutter_gemma` caps LiteRT around 4k.
  static const int _maxTokens = 2048;

  /// Long enough to exercise the same prefill path as real chat (short "hi" can pass while real prompts fail).
  static const String _warmupPrompt = r'''
You are PadhAI, a friendly AI tutor for Class 10 Mathematics. This student is preparing for SEE exam.

Rules:
- Explain in simple Nepali first, then English if needed
- Use Nepal examples (cities, rivers, festivals)
- Keep answers short and clear for Class 10 level

Student (Class 10, Mathematics):
hello

Teacher:
''';

  static const int _defaultTopK = 40;
  static const double _defaultTemperature = 0.7;
  static const int _maxPromptChars = 3200;

  InferenceModel? _model;
  var _status = GemmaModelStatus.notFound;
  String? _lastError;
  String? _modelPath;
  PreferredBackend? _lastBackendUsed;

  bool get isReady => _model != null;
  bool get isLoaded => _model != null;
  GemmaModelStatus get status => _status;
  String? get lastError => _lastError;
  String? get modelPath => _modelPath;

  /// Notifier for model status changes.
  final _statusController = StreamController<GemmaModelStatus>.broadcast();
  Stream<GemmaModelStatus> get statusStream => _statusController.stream;

  /// Platform check
  static bool get platformSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _releaseModelInstance() async {
    try {
      await _model?.close();
    } catch (e) {
      debugPrint('GemmaService: Model close: $e');
    }
    _model = null;
  }

  /// Finds and loads the model from device storage.
  ///
  /// Set [forceReload] to drop the native session after errors (e.g. LiteRT status 13).
  /// Set [tryOtherBackendFirst] to try the other backend(s) before the last one that worked
  /// (used after inference failures on the current backend).
  Future<bool> initialize({
    bool forceReload = false,
    bool tryOtherBackendFirst = false,
  }) async {
    if (!forceReload && _model != null) return true;

    if (forceReload) {
      await _releaseModelInstance();
    }

    if (_model != null) return true;

    _status = GemmaModelStatus.loading;
    _statusController.add(_status);

    try {
      final path = await ModelManager.findModel();
      if (path == null) {
        _status = GemmaModelStatus.notFound;
        _statusController.add(_status);
        _lastError = 'Model not found. Please copy gemma-4-E2B-it.litertlm to Downloads folder.';
        return false;
      }

      _modelPath = path;
      debugPrint('GemmaService: Initializing with model at $path');

      await FlutterGemma.initialize();

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(path).install();

      final backends = _liteRtBackendsToTry(
        lastUsed: _lastBackendUsed,
        preferOtherFirst: tryOtherBackendFirst,
      );

      Object? lastFailure;
      for (final backend in backends) {
        await _releaseModelInstance();
        try {
          debugPrint('GemmaService: Loading LiteRT with backend=$backend maxTokens=$_maxTokens');
          _model = await FlutterGemma.getActiveModel(
            maxTokens: _maxTokens,
            preferredBackend: backend,
          );

          debugPrint('GemmaService: Preflight warm-up (long prompt)...');
          final warmChat = await _model!.createChat();
          await warmChat.addQueryChunk(
            Message.text(text: _warmupPrompt, isUser: true),
          );
          final warmResp = await warmChat.generateChatResponse();
          final text = warmResp is TextResponse ? warmResp.token.trim() : '';
          if (text.isEmpty) {
            throw StateError('Warm-up returned empty text (same failure mode as chat).');
          }

          _lastBackendUsed = backend;
          debugPrint('GemmaService: Model ready on $backend (warm-up ok, ${text.length} chars).');
          _status = GemmaModelStatus.ready;
          _statusController.add(_status);
          return true;
        } catch (e, st) {
          debugPrint('GemmaService: Backend $backend failed: $e');
          debugPrint('$st');
          lastFailure = e;
          await _releaseModelInstance();
        }
      }

      throw lastFailure ?? StateError('No LiteRT backend succeeded');
    } catch (e, st) {
      debugPrint('GemmaService: Initialization failed: $e');
      debugPrint('$st');
      _lastError = e.toString();
      _status = GemmaModelStatus.error;
      _statusController.add(_status);
      return false;
    }
  }

  /// Legacy method name for compatibility
  Future<void> loadModel() async {
    await initialize();
  }

  /// Warm up (already done in initialize)
  Future<void> warmUp() async {
    // Already warmed up in initialize()
  }

  void dispose() {
    unawaited(_releaseModelInstance());
    _status = GemmaModelStatus.notFound;
    _statusController.close();
  }

  /// Full reply after generation finishes (no streaming).
  Future<String> runInference({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
  }) async {
    String? last;
    await for (final acc in runInferenceAccumulating(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
    )) {
      last = acc;
    }
    return last ?? '';
  }

  /// Yields the full answer-so-far as each token arrives (for responsive UI).
  Stream<String> runInferenceAccumulating({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    int? maxOutputTokens,
  }) async* {
    if (_model == null) {
      throw StateError('Model not initialized. Call initialize() first.');
    }

    final prompt = _buildOfflineInferencePrompt(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      maxChars: _maxPromptChars,
    );

    final outCap = maxOutputTokens ?? 384;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (_model == null) {
          yield _friendlyOfflineInferenceError(
            StateError('Model not loaded after reload.'),
          );
          return;
        }

        final chat = await _model!.createChat(
          topK: _defaultTopK,
          temperature: _defaultTemperature,
          isThinking: false,
          modelType: ModelType.gemmaIt,
        );

        await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

        var acc = '';
        var tokenCount = 0;

        await for (final response in chat.generateChatResponseAsync()) {
          if (response is TextResponse) {
            acc += response.token;
            tokenCount++;
            if (response.token.isNotEmpty) {
              yield acc;
            }
            if (tokenCount >= outCap) break;
          }
        }

        if (acc.trim().isEmpty) {
          debugPrint(
            'GemmaService: Empty model output (native prefill may have failed without a Dart exception).',
          );
          if (attempt == 0) {
            final ok = await initialize(
              forceReload: true,
              tryOtherBackendFirst: true,
            );
            if (ok) continue;
          }
          yield _friendlyEmptyLiteRtOutput();
          return;
        }
        return;
      } catch (e) {
        debugPrint('GemmaService: Inference error (attempt ${attempt + 1}): $e');
        final canRetry = attempt == 0 && _isLiteRtStatus13(e);
        if (canRetry) {
          final ok = await initialize(
            forceReload: true,
            tryOtherBackendFirst: true,
          );
          if (ok) continue;
        }
        yield _friendlyOfflineInferenceError(e);
        return;
      }
    }
  }
}
