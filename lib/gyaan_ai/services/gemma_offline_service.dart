import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import 'conversation_memory_manager.dart';
import 'gyaan_ai_system_prompt.dart';

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
  final int grade;
  final String subject;
  dynamic chat; // GemmaChat from flutter_gemma - mutable for recreation
  final List<ChatHistoryMessage> history;
  DateTime lastUsed;
  bool _disposed = false;

  /// Whether this session's Chat object was just created (fresh KV cache).
  /// CRITICAL: This is separate from history.isEmpty because we might create
  /// a new Chat object with history loaded from database - in that case,
  /// history is not empty but KV cache IS empty!
  bool _chatJustCreated = true;

  _ConversationSession({
    required this.sessionId,
    required this.grade,
    required this.subject,
    required this.chat,
    List<ChatHistoryMessage>? history,
  })  : history = history ?? [],
        lastUsed = DateTime.now();

  void addMessage(ChatHistoryMessage msg) {
    history.add(msg);
    lastUsed = DateTime.now();
  }

  /// Check if this session matches the given grade/subject
  bool matches(int g, String s) => grade == g && subject == s;

  /// Mark session as disposed (chat object no longer valid).
  /// Returns the old chat object so the caller can close its native session.
  dynamic takeChat() {
    _disposed = true;
    final c = chat;
    chat = null;
    return c;
  }

  /// Mark session as disposed without needing the chat reference.
  void markDisposed() {
    _disposed = true;
    chat = null;
  }

  bool get isDisposed => _disposed;

  /// Returns true if the Chat object was just created (KV cache is empty).
  /// Once we do a full context build, this becomes false.
  bool get isChatFresh => _chatJustCreated;

  /// Mark that the Chat object's KV cache has been populated.
  void markChatUsed() {
    _chatJustCreated = false;
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

/// Detects if user message is a continuation request.
/// ChatGPT-like behavior: "continue", "go on", "more", etc.
bool _isContinuationRequest(String message) {
  final lower = message.toLowerCase().trim();
  const continuePhrases = [
    'continue',
    'go on',
    'keep going',
    'more',
    'and then',
    'what else',
    'tell me more',
    'explain more',
    'जारी राख',
    'अझै',
    'थप',
  ];
  return continuePhrases.any((p) => lower == p || lower.startsWith('$p ') || lower.startsWith('$p,'));
}

/// Builds prompt with conversation history for context-aware responses.
/// Pattern from ChatGPT/Claude: include enough context for follow-up questions.
///
/// Key behaviors:
/// - Continuation requests ("continue", "more") get FULL last response
/// - Normal questions get recent turns with smart truncation
/// - Session isolation: each grade/subject has separate context
String _buildOfflineInferencePrompt({
  required int grade,
  required String subjectEnglish,
  required String userMessage,
  String? systemPrompt,
  required int maxChars,
  List<ChatHistoryMessage>? history,
  bool isLowRamDevice = true,
}) {
  String sanitize(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r'^\s*(Student|Teacher)\s*:\s*', multiLine: true), '');
    final lines = s.split('\n');
    final kept = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^[IWEFDV]/[A-Za-z0-9_().-]+\b').hasMatch(trimmed)) continue;
      if (trimmed.startsWith('<|turn') || trimmed.contains('<turn|>')) continue;
      kept.add(line);
    }
    return kept.join('\n').trim();
  }

  var system = systemPrompt ??
      buildGyaanAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);
  // System prompt truncation - AGGRESSIVE for fast prefill
  // Class 7 doesn't need verbose system prompts
  final maxSystemChars = isLowRamDevice ? 250 : 400;
  if (system.length > maxSystemChars) {
    system = system.substring(0, maxSystemChars);
  }

  final buffer = StringBuffer(system);
  buffer.write('\n\n');

  final cleanedUserMessage = sanitize(userMessage);
  final isContinuation = _isContinuationRequest(cleanedUserMessage);

  // Add conversation history for context
  if (history != null && history.isNotEmpty) {
    // For continuation: include last exchange (trimmed)
    // For normal: include only last 2 turns for speed
    final maxTurns = isContinuation ? 2 : (isLowRamDevice ? 2 : 4);
    final maxMsgChars = isContinuation ? 500 : (isLowRamDevice ? 200 : 350);

    final recentHistory = history.length > maxTurns
        ? history.sublist(history.length - maxTurns)
        : history;

    for (final msg in recentHistory) {
      final role = msg.role == 'user' ? 'Student' : 'Teacher';
      var content = sanitize(msg.content);
      if (content.isEmpty) continue;

      // For continuation requests, keep full last assistant response
      final isLastAssistantMsg = msg == recentHistory.last && msg.role == 'assistant';
      if (!isLastAssistantMsg && content.length > maxMsgChars) {
        content = '${content.substring(0, maxMsgChars)}…';
      }
      buffer.write('$role: $content\n\n');
    }
  }

  // Current user message - keep short for fast prefill
  var user = cleanedUserMessage.trim();
  final maxUserChars = isLowRamDevice ? 400 : 600;
  if (user.length > maxUserChars) {
    user = '${user.substring(0, maxUserChars)}…';
  }
  buffer.write('Student: $user\n\nTeacher:');

  var prompt = buffer.toString();
  if (prompt.length > maxChars) {
    // If too long, reduce history and retry
    if (history != null && history.length > 2) {
      return _buildOfflineInferencePrompt(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        maxChars: maxChars,
        history: history.sublist(history.length - 2), // Keep only last 2 messages
        isLowRamDevice: isLowRamDevice,
      );
    }
    if (history != null && history.isNotEmpty) {
      return _buildOfflineInferencePrompt(
        grade: grade,
        subjectEnglish: subjectEnglish,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        maxChars: maxChars,
        history: [], // Drop all history on overflow
        isLowRamDevice: isLowRamDevice,
      );
    }
    prompt = prompt.substring(0, maxChars);
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
///
/// Optimizations based on Google AI Edge Gallery patterns:
/// - Mutex to prevent concurrent inference calls
/// - Adaptive token limits based on device RAM
/// - Aggressive memory cleanup between inference calls
/// - Minimal session caching to reduce memory footprint
/// - History-aware prompt building with strict limits
///
/// NEW: Integrated ConversationMemoryManager for:
/// - Memory tiering (working memory + summary)
/// - Session isolation with UUID tracking
/// - Optimized prompt construction (primacy-recency pattern)
/// - Intelligent truncation at sentence boundaries
class GemmaOfflineService {
  /// KV / context budget - REDUCED for 2GB RAM devices.
  /// Google AI Edge Gallery uses ~512 for low-memory devices.
  /// Higher values cause OOM crashes and LiteRT status 13 errors.
  static const int _maxTokensLowRam = 768;   // For ≤3GB RAM (increased)
  static const int _maxTokensHighRam = 1024; // For >3GB RAM (increased)

  /// Actual max tokens used - set during initialization based on device RAM.
  int _effectiveMaxTokens = _maxTokensLowRam;

  /// Short warm-up - DISABLED by default on low-RAM devices.
  static const String _warmupPrompt =
      'You are GyaanAi tutor.\n\nStudent: hi\n\nTeacher:';

  /// Lower topK = fewer candidates per step = faster sampling on-device.
  /// SPEED: topK=3 for maximum speed (near-greedy, still good quality).
  static const int _defaultTopK = 3;

  /// Temperature for generation. 0.5 = faster, more focused responses.
  static const double _defaultTemperature = 0.5;

  /// Prompt context limits - AGGRESSIVE reduction for faster prefill.
  /// Smaller prompts = faster time-to-first-token (less freeze).
  /// Trade-off: less context, but much snappier response.
  ///
  /// OPTIMIZATION: Prefill freeze is ~proportional to prompt length.
  /// 500 chars ≈ 0.5-1s prefill, 800 chars ≈ 1-2s, 1200 chars ≈ 2-3s
  /// on a 2GHz device. Keeping prompts minimal for Class 7 level.
  static const int _maxPromptCharsLowRam = 500;
  static const int _maxPromptCharsHighRam = 700;
  int _effectiveMaxPromptChars = _maxPromptCharsLowRam;

  /// Max output tokens - increased for more complete answers.
  /// 512 tokens ≈ 350-400 words, good for Class 7 explanations.
  static const int _defaultMaxOutputTokens = 512;

  /// Inference timeout to prevent AI freezing.
  /// If inference takes longer than this, we abort and return partial response.
  static const Duration _inferenceTimeout = Duration(seconds: 60);

  /// Prefill timeout - if model takes too long to start generating, abort.
  static const Duration _prefillTimeout = Duration(seconds: 30);

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

  /// Conversation memory manager for intelligent context handling.
  /// Uses memory tiering, session isolation, and optimized prompt construction.
  late final ConversationMemoryManager _memoryManager;

  /// Flag to track if memory manager is initialized.
  bool _memoryManagerInitialized = false;

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
  /// CRITICAL: Now tracks grade/subject to detect cross-subject usage and prevent context bleeding.
  Future<_ConversationSession?> _getOrCreateSession(
    int sessionId, {
    required int grade,
    required String subject,
    List<ChatHistoryMessage>? initialHistory,
  }) async {
    if (_model == null) return null;

    // Check if existing session matches grade/subject
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;

      // CRITICAL: If grade/subject changed, invalidate and recreate!
      // This prevents context bleeding between different subjects
      if (!session.matches(grade, subject) || session.isDisposed) {
        debugPrint('GemmaService: Session $sessionId grade/subject mismatch or disposed, recreating');
        debugPrint('  Old: Grade ${session.grade} ${session.subject}');
        debugPrint('  New: Grade $grade $subject');
        final staleChat = session.takeChat();
        _sessions.remove(sessionId);
        await _closeNativeChat(staleChat);
        // Fall through to create new session
      } else {
        session.lastUsed = DateTime.now();
        return session;
      }
    }

    // Cleanup old sessions if we have too many
    if (_sessions.length >= _maxCachedSessions) {
      final oldest = _sessions.entries.reduce(
        (a, b) => a.value.lastUsed.isBefore(b.value.lastUsed) ? a : b,
      );
      final evictedChat = oldest.value.takeChat();
      _sessions.remove(oldest.key);
      await _closeNativeChat(evictedChat);
      debugPrint('GemmaService: Evicted oldest session ${oldest.key}');
    }

    // CRITICAL: Close the model's current native session before creating a new
    // one. flutter_gemma's createSession() reuses its _createCompleter if it
    // was never reset — meaning we'd silently get the OLD session back.
    // Closing via _closeNativeChat() fires the onClose callback which nulls
    // _createCompleter, so the next createChat() creates a truly fresh session.
    final currentModelChat = (_model as dynamic).chat;
    await _closeNativeChat(currentModelChat);

    // Create new chat session with FRESH context
    try {
      final chat = await _model!.createChat(
        topK: _defaultTopK,
        temperature: _defaultTemperature,
        isThinking: false,
        modelType: ModelType.gemmaIt,
      );

      final session = _ConversationSession(
        sessionId: sessionId,
        grade: grade,
        subject: subject,
        chat: chat,
        history: initialHistory,
      );
      _sessions[sessionId] = session;

      // CRITICAL: Invalidate memory manager's KV cache for this session.
      // Since we just created a fresh Chat object, any previous KV cache
      // validity state is now stale and must be reset.
      if (_memoryManagerInitialized) {
        _memoryManager.invalidateKvCache(sessionId);
      }

      debugPrint('GemmaService: Created new session $sessionId for Grade $grade $subject (KV cache invalidated)');
      return session;
    } catch (e) {
      debugPrint('GemmaService: Failed to create session: $e');
      return null;
    }
  }

  /// Clear a specific conversation session (e.g., when chat is cleared).
  /// Fire-and-forget closes the native session so flutter_gemma's
  /// _createCompleter is reset for the next createChat() call.
  void clearSession(int sessionId) {
    final session = _sessions[sessionId];
    if (session != null) {
      final chatObj = session.takeChat();
      unawaited(_closeNativeChat(chatObj));
    }
    _sessions.remove(sessionId);
    if (_memoryManagerInitialized) {
      _memoryManager.clearSession(sessionId);
    }
    debugPrint('GemmaService: Cleared session $sessionId');
  }

  /// Clear all conversation sessions.
  void clearAllSessions() {
    for (final session in _sessions.values) {
      final chatObj = session.takeChat();
      unawaited(_closeNativeChat(chatObj));
    }
    _sessions.clear();
    if (_memoryManagerInitialized) {
      _memoryManager.clearAllSessions();
    }
    debugPrint('GemmaService: Cleared all sessions');
  }

  /// Clear all sessions EXCEPT the specified one.
  void clearOtherSessions(int keepSessionId) {
    for (final entry in _sessions.entries) {
      if (entry.key != keepSessionId) {
        final chatObj = entry.value.takeChat();
        unawaited(_closeNativeChat(chatObj));
      }
    }
    _sessions.removeWhere((key, _) => key != keepSessionId);
    if (_memoryManagerInitialized) {
      _memoryManager.isolateSession(keepSessionId);
    }
    debugPrint('GemmaService: Isolated session $keepSessionId');
  }

  /// Force invalidate a session if grade/subject changed.
  void invalidateSessionIfMismatch(int sessionId, int grade, String subject) {
    final session = _sessions[sessionId];
    if (session != null && !session.matches(grade, subject)) {
      debugPrint('GemmaService: Invalidating session $sessionId - grade/subject mismatch');
      final chatObj = session.takeChat();
      unawaited(_closeNativeChat(chatObj));
      _sessions.remove(sessionId);
      if (_memoryManagerInitialized) {
        _memoryManager.clearSession(sessionId);
      }
    }
  }

  /// Close a flutter_gemma InferenceChat's native session.
  ///
  /// WHY THIS IS CRITICAL:
  /// flutter_gemma's MobileInferenceModel stores a single `_createCompleter`.
  /// That field is only set back to null when `session.close()` is called via
  /// the `onClose` callback. If we merely null-out the Dart `chat` reference
  /// (as the old `markDisposed()` did), `_createCompleter` keeps pointing at
  /// the old completed Completer. The next `createChat()` call then hits the
  /// guard:
  ///   if (_createCompleter case Completer c) { return c.future; }
  /// …and silently returns the OLD stale session — same KV cache, same subject
  /// context — even though we think we created a brand-new chat.
  ///
  /// Calling `session.close()` on the InferenceChat resets `_createCompleter`
  /// to null so the very next `createChat()` creates a truly fresh native
  /// inference session with an empty KV cache.
  Future<void> _closeNativeChat(dynamic chatObj) async {
    if (chatObj == null) return;
    try {
      // InferenceChat.session is a public `late` field; close() resets the
      // MobileInferenceModel's _createCompleter via the onClose callback.
      await (chatObj as dynamic).session?.close();
      debugPrint('GemmaService: Native session closed (KV cache reset)');
    } catch (e) {
      debugPrint('GemmaService: Native session close error (non-critical): $e');
    }
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
  ///
  /// NOTE: ProcessInfo.maxRss returns app memory limit, NOT device RAM.
  /// Since we can't reliably detect device RAM without a plugin, we use
  /// platform-based heuristics. Most modern Android devices (2020+) have 4GB+.
  Future<void> _detectDeviceRamAndSetLimits() async {
    try {
      // ProcessInfo gives us app memory, not device RAM
      // Use it as a hint: if app is allowed >1GB, device likely has 4GB+
      final maxRss = ProcessInfo.maxRss;
      final maxRssGb = maxRss > 0 ? maxRss / (1024 * 1024 * 1024) : 0.0;

      // Heuristic: Android gives apps roughly 25-50% of device RAM
      // If maxRss > 1GB, device likely has 4GB+ RAM
      // If maxRss > 512MB, device likely has 3GB+ RAM
      if (maxRssGb >= 1.0) {
        _deviceRamGb = 6.0; // Assume high-RAM device
      } else if (maxRssGb >= 0.5) {
        _deviceRamGb = 4.0; // Assume mid-RAM device
      } else if (maxRssGb > 0) {
        _deviceRamGb = 3.0; // Conservative estimate
      } else {
        // If we can't detect, assume modern device with decent RAM
        // Most devices running this app (2020+) have at least 4GB
        _deviceRamGb = 4.0;
      }

      debugPrint('GemmaService: RAM heuristic: ~${_deviceRamGb.toStringAsFixed(1)}GB (app maxRss=${maxRssGb.toStringAsFixed(2)}GB)');
    } catch (e) {
      // Default to standard settings for modern devices
      _deviceRamGb = 4.0;
      debugPrint('GemmaService: RAM detection failed, assuming 4GB modern device: $e');
    }

    // Set adaptive limits based on estimated RAM
    // OPTIMIZATION: Use smaller prompts even on high-RAM to reduce prefill freeze
    if (_deviceRamGb <= 3.0) {
      // Low RAM device: minimal settings
      _effectiveMaxTokens = _maxTokensLowRam;
      _effectiveMaxPromptChars = _maxPromptCharsLowRam;
      debugPrint('GemmaService: Using LOW-RAM settings (maxTokens=$_effectiveMaxTokens, maxPromptChars=$_effectiveMaxPromptChars)');
    } else {
      // Standard/High RAM device
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

    // Initialize memory manager with appropriate config
    if (!_memoryManagerInitialized) {
      _memoryManager = ConversationMemoryManager(
        config: _isLowRamDevice ? MemoryConfig.lowRam : MemoryConfig.standard,
      );
      _memoryManagerInitialized = true;
      debugPrint('GemmaService: Memory manager initialized (${_isLowRamDevice ? "low-RAM" : "standard"} config)');
    }

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
          bool isFreshChat = false;  // True if Chat object was just created (empty KV cache)
          _ConversationSession? session;

          if (sessionId != null) {
            session = await _getOrCreateSession(
              sessionId,
              grade: grade,
              subject: subjectEnglish,
              initialHistory: history,
            );
            if (session != null) {
              chat = session.chat;
              // CRITICAL FIX: Use isChatFresh instead of history.isEmpty!
              // A session can have history from DB but a fresh Chat object (empty KV cache).
              // Using history.isEmpty caused context bleeding because it would skip
              // full context rebuild when history existed but KV cache was empty.
              isFreshChat = session.isChatFresh;
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
            isFreshChat = true;
          }

          // CONTEXT MANAGEMENT using ConversationMemoryManager:
          // - Memory tiering: working memory (verbatim) + summary (compressed)
          // - Primacy-recency pattern: system at start, recent context at end
          // - Intelligent sentence-boundary truncation
          // - Session isolation with UUID tracking
          //
          // Key insight: When app restarts, KV cache is lost but DB has history.
          // The memory manager handles rebuilding context efficiently.
          String promptToSend;
          final hasDbHistory = history != null && history.isNotEmpty;
          final hasSessionHistory = session != null && session.history.isNotEmpty;
          final isContinuation = _isContinuationRequest(userMessage);

          // Use memory manager for intelligent context building
          if (_memoryManagerInitialized && sessionId != null) {
            final system = systemPrompt ??
                buildGyaanAiSystemPrompt(grade: grade, subjectEnglish: subjectEnglish);

            // Check if we can reuse KV cache (fast path)
            // CRITICAL: Must NOT be a fresh chat AND KV cache must be valid AND session grade/subject must still match
            final kvCacheValid = _memoryManager.isKvCacheValid(sessionId);
            final sessionMatchesContext = session != null && session.matches(grade, subjectEnglish);

            if (!isFreshChat && hasSessionHistory && !isContinuation && kvCacheValid && sessionMatchesContext) {
              // FAST PATH: KV cache active, just send new message
              // This is 2-3x faster! (Skip prefill of system+history tokens)
              promptToSend = userMessage.trim();
              if (promptToSend.length > 600) {
                promptToSend = '${promptToSend.substring(0, 600)}…';
              }
              debugPrint('GemmaService: REUSING KV cache - sending only user message (${promptToSend.length} chars)');
            } else {
              // Use memory manager for intelligent context building
              // This handles: DB rebuild, continuation, new session, all paths
              promptToSend = _memoryManager.buildPromptWithContext(
                sessionId: sessionId,
                grade: grade,
                subject: subjectEnglish,
                systemPrompt: system,
                userMessage: userMessage,
                dbHistory: history,
              );

              // Mark KV cache as valid after full context build
              _memoryManager.markKvCacheValid(sessionId);

              // Mark the Chat object as used (no longer fresh)
              session?.markChatUsed();

              final pathType = isFreshChat
                  ? (hasDbHistory ? 'REBUILD from DB' : 'NEW session')
                  : (isContinuation ? 'CONTINUATION' : 'CONTEXT refresh');
              debugPrint('GemmaService: $pathType via MemoryManager (${promptToSend.length} chars)');
            }
          } else {
            // Fallback to legacy prompt building (no session ID)
            promptToSend = _buildOfflineInferencePrompt(
              grade: grade,
              subjectEnglish: subjectEnglish,
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              maxChars: _effectiveMaxPromptChars,
              history: history,
              isLowRamDevice: _isLowRamDevice,
            );
            debugPrint('GemmaService: LEGACY prompt building (${promptToSend.length} chars)');
          }

          // Signal that we're starting prefill (UI can show "preparing...")
          // This prevents the "freeze" feeling - user sees immediate feedback
          debugPrint('GemmaService: Starting prefill (${promptToSend.length} chars)...');

          // Add prefill timeout to prevent freezing during model preparation
          try {
            await chat.addQueryChunk(Message.text(text: promptToSend, isUser: true))
                .timeout(_prefillTimeout, onTimeout: () {
              throw TimeoutException('Model prefill took too long', _prefillTimeout);
            });
          } on TimeoutException catch (e) {
            debugPrint('GemmaService: Prefill timeout: $e');
            yield 'Response timed out during preparation. Please try again with a shorter message.';
            return;
          }

          final prefillMs = sw.elapsedMilliseconds;
          debugPrint('GemmaService: prefill ${prefillMs}ms (prompt: ${promptToSend.length} chars)');

          var acc = '';
          var tokenCount = 0;
          // SPEED: Yield every token for smoother word-by-word display
          const yieldEveryNTokens = 1;

          // Track last token time for stall detection
          var lastTokenTime = DateTime.now();
          const stallThreshold = Duration(seconds: 15);

          await for (final response in chat.generateChatResponseAsync()) {
            // Check for inference timeout
            if (sw.elapsed > _inferenceTimeout) {
              debugPrint('GemmaService: Inference timeout after ${sw.elapsedMilliseconds}ms');
              if (acc.isNotEmpty) {
                yield '$acc\n\n(Response truncated due to time limit)';
              } else {
                yield 'Response timed out. Please try again with a simpler question.';
              }
              return;
            }

            // Check for stall (no tokens for too long)
            final now = DateTime.now();
            if (now.difference(lastTokenTime) > stallThreshold && tokenCount > 0) {
              debugPrint('GemmaService: Generation stalled after $tokenCount tokens');
              if (acc.isNotEmpty) {
                yield '$acc\n\n(Generation stopped - model stalled)';
              }
              return;
            }

            if (response is TextResponse) {
              if (response.token.isEmpty) continue;
              acc += response.token;
              tokenCount++;
              lastTokenTime = now;
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

          // Also update memory manager with the new messages
          if (_memoryManagerInitialized && sessionId != null) {
            _memoryManager.addMessage(
              sessionId: sessionId,
              message: ChatHistoryMessage(
                role: 'user',
                content: userMessage,
                timestamp: DateTime.now(),
              ),
              grade: grade,
              subject: subjectEnglish,
            );
            _memoryManager.addMessage(
              sessionId: sessionId,
              message: ChatHistoryMessage(
                role: 'assistant',
                content: acc,
                timestamp: DateTime.now(),
              ),
              grade: grade,
              subject: subjectEnglish,
            );
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
