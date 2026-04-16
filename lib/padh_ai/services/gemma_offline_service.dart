import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import 'padh_ai_system_prompt.dart';

/// Represents a message in chat history for context building.
class ChatHistoryMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatHistoryMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  @override
  String toString() =>
      role == 'user' ? 'Student: $content' : 'Teacher: $content';
}

/// Tracks active conversation session for engine reuse.
/// Note: Using dynamic for chat since flutter_gemma doesn't export Chat type directly.
class _ConversationSession {
  final int sessionId;
  final dynamic chat; // GemmaChat from flutter_gemma
  final List<ChatHistoryMessage> history;
  DateTime lastUsed;

  _ConversationSession({
    required this.sessionId,
    required this.chat,
    List<ChatHistoryMessage>? history,
  })  : history = history ?? [],
        lastUsed = DateTime.now();

  void addMessage(ChatHistoryMessage msg) {
    history.add(msg);
    lastUsed = DateTime.now();
  }
}

/// Status of the Gemma model.
enum GemmaModelStatus {
  notFound,
  loading,
  ready,
  error,
}

/// Manages finding the model file on the device.
/// Checks, in order: app Documents (in-app download), app-specific external files
/// ([getExternalStorageDirectory] — usable after `adb push` without broad storage
/// permission on Android 13+), app Support dir, then public Download paths.
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

    // 1b. App-specific external files (Android: …/Android/data/<package>/files/).
    // Preferred for adb/cable installs on modern Android: no READ_MEDIA_* / MANAGE
    // storage needed to read this path, unlike public Download/.
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final extFile = File('${extDir.path}/$modelFileName');
        if (await extFile.exists()) {
          final len = await extFile.length();
          if (len >= minSideLoadedModelBytes) {
            debugPrint('ModelManager: Found model in app external files: ${extFile.path}');
            return extFile.path;
          }
          debugPrint(
            'ModelManager: App external model too small (${extFile.path}, $len bytes)',
          );
        }
      }
    } catch (e) {
      debugPrint('ModelManager: Error checking app external files: $e');
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

/// Builds prompt with conversation history for context-aware responses.
/// Pattern from Google AI Edge Gallery: format chat history before new message.
/// OPTIMIZED for 2GB RAM devices: minimal history, shorter truncation.
String _buildOfflineInferencePrompt({
  required int grade,
  required String subjectEnglish,
  required String userMessage,
  String? systemPrompt,
  required int maxChars,
  List<ChatHistoryMessage>? history,
}) {
  var system = systemPrompt ??
      buildPadhAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);
  // REDUCED: Shorter system prompt = faster prefill, less memory
  if (system.length > 350) {
    system = system.substring(0, 350);
  }

  final buffer = StringBuffer(system);
  buffer.write('\n\n');

  // Add conversation history for context (like AICore's formatChatPrompt)
  // REDUCED from 6 to 3 turns for low-RAM devices
  if (history != null && history.isNotEmpty) {
    // Take last 3 turns only (reduced from 6)
    final recentHistory = history.length > 3
        ? history.sublist(history.length - 3)
        : history;

    for (final msg in recentHistory) {
      final role = msg.role == 'user' ? 'Student' : 'Teacher';
      var content = msg.content.trim();
      // REDUCED: Truncate history messages to 150 chars (was 300)
      if (content.length > 150) {
        content = '${content.substring(0, 150)}…';
      }
      buffer.write('$role: $content\n\n');
    }
  }

  // Current user message - REDUCED truncation limit
  var user = userMessage.trim();
  if (user.length > 500) {
    user = '${user.substring(0, 500)}…';
  }
  buffer.write('Student: $user\n\nTeacher:');

  var prompt = buffer.toString();
  if (prompt.length > maxChars) {
    // If too long, drop all history and retry
    if (history != null && history.isNotEmpty) {
      return _buildOfflineInferencePrompt(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        maxChars: maxChars,
        history: [], // Drop all history on overflow
      );
    }
    prompt = prompt.substring(0, maxChars);
  }
  return prompt;
}

/// Check if a question is similar to one already in history.
/// Returns the previous answer if found, null otherwise.
String? _findSimilarQuestionInHistory(
  String question,
  List<ChatHistoryMessage> history,
) {
  if (history.isEmpty) return null;

  final normalized = question.toLowerCase().trim();
  // Remove common filler words for comparison
  final keywords = normalized
      .replaceAll(RegExp(r'\b(what|is|the|a|an|how|why|when|where|can|you|please|explain|tell|me|about)\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (keywords.length < 5) return null;

  for (var i = 0; i < history.length - 1; i++) {
    final msg = history[i];
    if (msg.role != 'user') continue;

    final prevNormalized = msg.content.toLowerCase().trim();
    final prevKeywords = prevNormalized
        .replaceAll(RegExp(r'\b(what|is|the|a|an|how|why|when|where|can|you|please|explain|tell|me|about)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Check for high similarity
    if (keywords == prevKeywords ||
        (keywords.length > 10 && prevKeywords.contains(keywords)) ||
        (prevKeywords.length > 10 && keywords.contains(prevKeywords))) {
      // Find the corresponding assistant response
      for (var j = i + 1; j < history.length; j++) {
        if (history[j].role == 'assistant') {
          return history[j].content;
        }
      }
    }
  }
  return null;
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
///
/// Optimizations based on Google AI Edge Gallery patterns:
/// - Mutex to prevent concurrent inference calls
/// - Adaptive token limits based on device RAM
/// - Aggressive memory cleanup between inference calls
/// - Minimal session caching to reduce memory footprint
/// - History-aware prompt building with strict limits
class GemmaOfflineService {
  /// KV / context budget - REDUCED for 2GB RAM devices.
  /// Google AI Edge Gallery uses ~512 for low-memory devices.
  /// Higher values cause OOM crashes and LiteRT status 13 errors.
  static const int _maxTokensLowRam = 384;  // For ≤3GB RAM
  static const int _maxTokensHighRam = 512; // For >3GB RAM

  /// Actual max tokens used - set during initialization based on device RAM.
  int _effectiveMaxTokens = _maxTokensLowRam;

  /// Short warm-up - DISABLED by default on low-RAM devices.
  static const String _warmupPrompt =
      'You are GyaanAi tutor.\n\nStudent: hi\n\nTeacher:';

  /// Lower topK = fewer candidates per step = faster sampling on-device.
  /// SPEED: Reduced to 5 for maximum speed (quality stays good for education).
  static const int _defaultTopK = 5;

  /// Temperature for generation. 0.7 = good balance of speed and quality.
  static const double _defaultTemperature = 0.7;

  /// REDUCED prompt context for low-RAM devices.
  static const int _maxPromptCharsLowRam = 1200;
  static const int _maxPromptCharsHighRam = 1800;
  int _effectiveMaxPromptChars = _maxPromptCharsLowRam;

  /// Max output tokens - REDUCED for faster responses and less memory.
  static const int _defaultMaxOutputTokens = 128;

  InferenceModel? _model;
  var _status = GemmaModelStatus.notFound;
  String? _lastError;
  String? _modelPath;
  PreferredBackend? _lastBackendUsed;

  /// Mutex to prevent concurrent inference calls (like Google Gallery pattern).
  /// Uses Completer-based lock since Dart doesn't have native mutex.
  Completer<void>? _inferenceLock;

  /// Active conversation sessions by DB session ID.
  /// REDUCED to 1-2 sessions to minimize memory usage on low-RAM devices.
  final Map<int, _ConversationSession> _sessions = {};

  /// Maximum number of cached sessions - REDUCED from 5 to 2 for low RAM.
  /// Each session holds a Chat object which consumes significant memory.
  static const int _maxCachedSessions = 2;

  /// Device RAM in GB - detected at initialization.
  double _deviceRamGb = 2.0;

  /// Whether this is a low-RAM device (≤3GB).
  bool get _isLowRamDevice => _deviceRamGb <= 3.0;

  bool get isReady => _model != null;
  bool get isLoaded => _model != null;
  GemmaModelStatus get status => _status;
  String? get lastError => _lastError;
  String? get modelPath => _modelPath;
  bool get isInferenceRunning => _inferenceLock != null;

  /// Notifier for model status changes.
  final _statusController = StreamController<GemmaModelStatus>.broadcast();
  Stream<GemmaModelStatus> get statusStream => _statusController.stream;

  /// Platform check
  static bool get platformSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Acquire inference lock - prevents concurrent inference calls.
  /// Pattern from Google AI Edge Gallery: ensures single inference at a time.
  Future<void> _acquireLock() async {
    while (_inferenceLock != null) {
      await _inferenceLock!.future;
    }
    _inferenceLock = Completer<void>();
  }

  /// Release inference lock.
  void _releaseLock() {
    final lock = _inferenceLock;
    _inferenceLock = null;
    lock?.complete();
  }

  /// Get or create a conversation session for the given DB session ID.
  Future<_ConversationSession?> _getOrCreateSession(
    int sessionId, {
    List<ChatHistoryMessage>? initialHistory,
  }) async {
    if (_model == null) return null;

    // Return existing session if available
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;
      session.lastUsed = DateTime.now();
      return session;
    }

    // Cleanup old sessions if we have too many
    if (_sessions.length >= _maxCachedSessions) {
      final oldest = _sessions.entries.reduce(
        (a, b) => a.value.lastUsed.isBefore(b.value.lastUsed) ? a : b,
      );
      _sessions.remove(oldest.key);
    }

    // Create new chat session
    try {
      final chat = await _model!.createChat(
        topK: _defaultTopK,
        temperature: _defaultTemperature,
        isThinking: false,
        modelType: ModelType.gemmaIt,
      );

      final session = _ConversationSession(
        sessionId: sessionId,
        chat: chat,
        history: initialHistory,
      );
      _sessions[sessionId] = session;
      return session;
    } catch (e) {
      debugPrint('GemmaService: Failed to create session: $e');
      return null;
    }
  }

  /// Clear a specific conversation session (e.g., when chat is cleared).
  void clearSession(int sessionId) {
    _sessions.remove(sessionId);
  }

  /// Clear all conversation sessions.
  void clearAllSessions() {
    _sessions.clear();
  }

  Future<void> _releaseModelInstance() async {
    clearAllSessions();
    try {
      await _model?.close();
    } catch (e) {
      debugPrint('GemmaService: Model close: $e');
    }
    _model = null;
  }

  /// Detect device RAM and set adaptive token/context limits.
  /// Pattern from Google AI Edge Gallery: use minDeviceMemoryInGb thresholds.
  Future<void> _detectDeviceRamAndSetLimits() async {
    try {
      // Try to get device RAM via ProcessInfo (available on mobile)
      final rss = ProcessInfo.currentRss;
      final maxRss = ProcessInfo.maxRss;

      // Estimate total RAM from maxRss (rough heuristic)
      // On Android/iOS, maxRss is often limited but gives us a hint
      if (maxRss > 0) {
        // Convert bytes to GB
        _deviceRamGb = maxRss / (1024 * 1024 * 1024);
        // If maxRss is unreasonably small, use a floor
        if (_deviceRamGb < 1.0) _deviceRamGb = 2.0;
        // Cap at reasonable max for heuristic
        if (_deviceRamGb > 16.0) _deviceRamGb = 4.0;
      } else {
        // Default to conservative low-RAM assumption
        _deviceRamGb = 2.0;
      }

      debugPrint('GemmaService: Detected ~${_deviceRamGb.toStringAsFixed(1)}GB RAM (rss=$rss, maxRss=$maxRss)');
    } catch (e) {
      // If ProcessInfo fails, assume low RAM for safety
      _deviceRamGb = 2.0;
      debugPrint('GemmaService: RAM detection failed, assuming 2GB: $e');
    }

    // Set adaptive limits based on detected RAM
    if (_deviceRamGb <= 3.0) {
      // Low RAM device: use minimal settings
      _effectiveMaxTokens = _maxTokensLowRam;
      _effectiveMaxPromptChars = _maxPromptCharsLowRam;
      debugPrint('GemmaService: Using LOW-RAM settings (maxTokens=$_effectiveMaxTokens, maxPromptChars=$_effectiveMaxPromptChars)');
    } else {
      // Higher RAM device: can use slightly more context
      _effectiveMaxTokens = _maxTokensHighRam;
      _effectiveMaxPromptChars = _maxPromptCharsHighRam;
      debugPrint('GemmaService: Using STANDARD settings (maxTokens=$_effectiveMaxTokens, maxPromptChars=$_effectiveMaxPromptChars)');
    }
  }

  /// Finds and loads the model from device storage.
  ///
  /// Set [forceReload] to drop the native session after errors (e.g. LiteRT status 13).
  /// Set [tryOtherBackendFirst] to try the other backend(s) before the last one that worked
  /// (used after inference failures on the current backend).
  ///
  /// Set [skipWarmup] to load LiteRT without running a full preflight generation (splash screen).
  /// First real chat still validates the session; [runInferenceAccumulating] can retry backends.
  Future<bool> initialize({
    bool forceReload = false,
    bool tryOtherBackendFirst = false,
    bool skipWarmup = false,
  }) async {
    if (!forceReload && _model != null) return true;

    if (forceReload) {
      await _releaseModelInstance();
    }

    if (_model != null) return true;

    _status = GemmaModelStatus.loading;
    _statusController.add(_status);

    // Detect device RAM and set adaptive limits (Google AI Edge Gallery pattern)
    await _detectDeviceRamAndSetLimits();

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
          debugPrint('GemmaService: Loading LiteRT with backend=$backend maxTokens=$_effectiveMaxTokens (RAM: ${_deviceRamGb.toStringAsFixed(1)}GB)');
          _model = await FlutterGemma.getActiveModel(
            maxTokens: _effectiveMaxTokens,
            preferredBackend: backend,
          );

          // SKIP warmup on low-RAM devices to save memory and prevent OOM
          final shouldSkipWarmup = skipWarmup || _isLowRamDevice;
          if (!shouldSkipWarmup) {
            debugPrint('GemmaService: Preflight warm-up...');
            final warmChat = await _model!.createChat();
            await warmChat.addQueryChunk(
              Message.text(text: _warmupPrompt, isUser: true),
            );
            final warmResp = await warmChat.generateChatResponse();
            final text = warmResp is TextResponse ? warmResp.token.trim() : '';
            if (text.isEmpty) {
              throw StateError('Warm-up returned empty text (same failure mode as chat).');
            }
            debugPrint(
              'GemmaService: Model ready on $backend (warm-up ok, ${text.length} chars).',
            );
          } else {
            debugPrint(
              'GemmaService: Model loaded on $backend (warm-up skipped for ${_isLowRamDevice ? "low-RAM device" : "fast startup"}).',
            );
          }

          _lastBackendUsed = backend;
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

  /// Optional no-op; preflight warm-up runs in [initialize] unless [skipWarmup] was true.
  Future<void> warmUp() async {}

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
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async {
    String? last;
    await for (final acc in runInferenceAccumulating(
      grade: grade,
      subjectEnglish: subjectEnglish,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      sessionId: sessionId,
      history: history,
    )) {
      last = acc;
    }
    return last ?? '';
  }

  /// Yields the full answer-so-far as each token arrives (for responsive UI).
  ///
  /// KEY OPTIMIZATION: Reuses KV cache from existing sessions (like Google AI Edge).
  /// - First message in session: sends full prompt with system context
  /// - Subsequent messages: sends ONLY the new user message (KV cache has history)
  /// - This is 2-3x faster than rebuilding prompt every turn
  Stream<String> runInferenceAccumulating({
    required int grade,
    required String subjectEnglish,
    required String userMessage,
    String? systemPrompt,
    int? maxOutputTokens,
    int? sessionId,
    List<ChatHistoryMessage>? history,
  }) async* {
    if (_model == null) {
      throw StateError('Model not initialized. Call initialize() first.');
    }

    // Acquire mutex lock (skip similar question check for speed)
    await _acquireLock();

    try {
      final outCap = maxOutputTokens ?? _defaultMaxOutputTokens;

      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          if (_model == null) {
            yield _friendlyOfflineInferenceError(
              StateError('Model not loaded after reload.'),
            );
            return;
          }

          final sw = Stopwatch()..start();

          // KEY OPTIMIZATION: Reuse session chat with KV cache (like Google does)
          dynamic chat;
          bool isNewSession = false;
          _ConversationSession? session;

          if (sessionId != null) {
            session = await _getOrCreateSession(sessionId, initialHistory: history);
            if (session != null) {
              chat = session.chat;
              isNewSession = session.history.isEmpty;
            }
          }

          // Fallback: create new chat if no session
          if (chat == null) {
            chat = await _model!.createChat(
              topK: _defaultTopK,
              temperature: _defaultTemperature,
              isThinking: false,
              modelType: ModelType.gemmaIt,
            );
            isNewSession = true;
          }

          // CRITICAL SPEED FIX:
          // - New session: send full prompt with system context (first turn)
          // - Existing session: send ONLY user message (KV cache has context!)
          // This is what makes Google's app faster - they reuse the KV cache
          String promptToSend;
          if (isNewSession) {
            // First turn: include system prompt and context
            promptToSend = _buildOfflineInferencePrompt(
              grade: grade,
              subjectEnglish: subjectEnglish,
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              maxChars: _effectiveMaxPromptChars,
              history: null, // No history needed - it's the first turn
            );
            debugPrint('GemmaService: NEW session - sending full prompt (${promptToSend.length} chars)');
          } else {
            // Subsequent turns: KV cache already has context, just send new message
            // This is 2-3x faster! (Skip prefill of system+history tokens)
            promptToSend = userMessage.trim();
            if (promptToSend.length > 500) {
              promptToSend = '${promptToSend.substring(0, 500)}…';
            }
            debugPrint('GemmaService: REUSING KV cache - sending only user message (${promptToSend.length} chars)');
          }

          await chat.addQueryChunk(Message.text(text: promptToSend, isUser: true));
          final prefillMs = sw.elapsedMilliseconds;
          debugPrint('GemmaService: prefill ${prefillMs}ms');

          var acc = '';
          var tokenCount = 0;
          // SPEED: Yield every 3 tokens (faster than time-based checks)
          const yieldEveryNTokens = 3;

          await for (final response in chat.generateChatResponseAsync()) {
            if (response is TextResponse) {
              if (response.token.isEmpty) continue;
              acc += response.token;
              tokenCount++;
              // Yield every N tokens - simpler and faster than DateTime checks
              if (tokenCount % yieldEveryNTokens == 0 || tokenCount >= outCap) {
                yield acc;
              }
              if (tokenCount >= outCap) break;
            }
          }
          // Final yield for remaining tokens
          yield acc;

          final elapsed = sw.elapsedMilliseconds;
          final tps = elapsed > 0 ? (tokenCount * 1000 / elapsed).toStringAsFixed(1) : '?';
          final ttft = prefillMs; // Time to first token approximation
          debugPrint('GemmaService: $tokenCount tokens in ${elapsed}ms ($tps tok/s, TTFT: ${ttft}ms)');

          // Update session history for KV cache context tracking
          if (session != null) {
            session.addMessage(ChatHistoryMessage(
              role: 'user',
              content: userMessage,
              timestamp: DateTime.now(),
            ));
            session.addMessage(ChatHistoryMessage(
              role: 'assistant',
              content: acc,
              timestamp: DateTime.now(),
            ));
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
            // Clear session on error
            if (sessionId != null) clearSession(sessionId);
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
    } finally {
      // Always release lock
      _releaseLock();

      // AGGRESSIVE CLEANUP for low-RAM devices (Google AI Edge Gallery pattern)
      if (_isLowRamDevice) {
        _cleanupMemory();
      }
    }
  }

  /// Aggressive memory cleanup for low-RAM devices.
  /// Clears old sessions and hints to Dart GC.
  void _cleanupMemory() {
    // Keep only the most recent session (if any)
    if (_sessions.length > 1) {
      final newest = _sessions.entries.reduce(
        (a, b) => a.value.lastUsed.isAfter(b.value.lastUsed) ? a : b,
      );
      final toRemove = _sessions.keys.where((k) => k != newest.key).toList();
      for (final k in toRemove) {
        _sessions.remove(k);
      }
      debugPrint('GemmaService: Cleaned up ${toRemove.length} old sessions');
    }

    // Truncate session history to last 2 messages only
    for (final session in _sessions.values) {
      if (session.history.length > 4) {
        final keep = session.history.sublist(session.history.length - 4);
        session.history.clear();
        session.history.addAll(keep);
      }
    }
  }

  /// Force cleanup of all sessions and model for extreme memory pressure.
  Future<void> releaseForMemoryPressure() async {
    debugPrint('GemmaService: Releasing all resources due to memory pressure');
    await _releaseModelInstance();
    _status = GemmaModelStatus.notFound;
    _statusController.add(_status);
  }
}
