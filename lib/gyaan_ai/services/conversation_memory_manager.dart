import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'gemma_offline_service.dart';

/// Memory tier for conversation context management.
/// Based on research: "Memory tiering applies OS memory hierarchy concepts to LLM context"
/// Reference: MemGPT virtual context management pattern
enum MemoryTier {
  working,   // Active conversation - kept verbatim (last N messages)
  shortTerm, // Session storage - summarized recent context
  longTerm,  // Persistent information - key facts only
}

/// Represents a conversation turn (user + assistant pair)
class ConversationTurn {
  final ChatHistoryMessage userMessage;
  final ChatHistoryMessage? assistantMessage;
  final DateTime timestamp;

  ConversationTurn({
    required this.userMessage,
    this.assistantMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalLength =>
      userMessage.content.length + (assistantMessage?.content.length ?? 0);

  @override
  String toString() {
    final user = 'Student: ${userMessage.content}';
    final assistant = assistantMessage != null
        ? '\nTeacher: ${assistantMessage!.content}'
        : '';
    return '$user$assistant';
  }
}

/// Session metadata for isolation and tracking
class SessionContext {
  final String uuid;
  final int sessionId;
  final int grade;
  final String subject;
  final DateTime createdAt;
  DateTime lastAccessedAt;

  /// Summarized context from older messages (memory tier: shortTerm)
  String? contextSummary;

  /// Key facts extracted from conversation (memory tier: longTerm)
  List<String> keyFacts;

  /// Working memory: recent turns kept verbatim
  final Queue<ConversationTurn> workingMemory;

  /// Total message count in this session
  int messageCount;

  /// Flag to indicate if KV cache is valid
  bool kvCacheValid;

  SessionContext({
    required this.sessionId,
    required this.grade,
    required this.subject,
    String? uuid,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = DateTime.now(),
        lastAccessedAt = DateTime.now(),
        contextSummary = null,
        keyFacts = [],
        workingMemory = Queue<ConversationTurn>(),
        messageCount = 0,
        kvCacheValid = false;

  void touch() {
    lastAccessedAt = DateTime.now();
  }

  void invalidateKvCache() {
    kvCacheValid = false;
  }

  void markKvCacheValid() {
    kvCacheValid = true;
  }
}

/// Configuration for memory management
class MemoryConfig {
  /// Maximum turns to keep in working memory (verbatim)
  final int maxWorkingMemoryTurns;

  /// Maximum characters for context summary
  final int maxSummaryChars;

  /// Threshold to trigger summarization (message count)
  final int summarizationThreshold;

  /// Maximum total prompt characters
  final int maxPromptChars;

  /// Maximum characters per message before truncation
  final int maxMessageChars;

  /// Whether to use intelligent sentence boundary truncation
  final bool useSentenceBoundary;

  const MemoryConfig({
    this.maxWorkingMemoryTurns = 4,
    this.maxSummaryChars = 400,
    this.summarizationThreshold = 8,
    this.maxPromptChars = 2400,
    this.maxMessageChars = 500,
    this.useSentenceBoundary = true,
  });

  /// Low RAM device configuration
  static const lowRam = MemoryConfig(
    maxWorkingMemoryTurns: 3,
    maxSummaryChars: 150,
    summarizationThreshold: 6,
    maxPromptChars: 650,
    maxMessageChars: 200,
    useSentenceBoundary: true,
  );

  /// Standard RAM device configuration
  static const standard = MemoryConfig(
    maxWorkingMemoryTurns: 3,
    maxSummaryChars: 220,
    summarizationThreshold: 8,
    maxPromptChars: 900,
    maxMessageChars: 280,
    useSentenceBoundary: true,
  );
}

/// Conversation Memory Manager
///
/// Implements professional-grade context management based on:
/// - Google AI Edge Gallery patterns
/// - ChatGPT/Claude context management
/// - Research on LLM memory tiering and hallucination prevention
///
/// Key features:
/// 1. Memory tiering: working memory (verbatim) + summary (compressed) + key facts
/// 2. Sliding window with intelligent summarization
/// 3. Session isolation with UUID tracking
/// 4. Optimized prompt construction to avoid "lost in middle" problem
/// 5. Intelligent truncation at sentence boundaries
class ConversationMemoryManager {
  ConversationMemoryManager({
    MemoryConfig? config,
  }) : _config = config ?? MemoryConfig.standard;

  final MemoryConfig _config;

  String _sanitizeForPrompt(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;

    // Remove common "role injection" prefixes if user pasted chat transcripts.
    s = s.replaceAll(RegExp(r'^\s*(Student|Teacher)\s*:\s*', multiLine: true), '');

    // Drop Android/Flutter log-style lines that students might paste.
    final lines = s.split('\n');
    final kept = <String>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;

      // Examples:
      // "I/flutter (14889): ..."
      // "E/tflite  (14889): ..."
      // "W/LiteRtLmSession(14889): ..."
      if (RegExp(r'^[IWEFDV]/[A-Za-z0-9_().-]+\b').hasMatch(trimmed)) {
        continue;
      }
      if (trimmed.startsWith('<|turn') || trimmed.contains('<turn|>')) continue;
      if (trimmed.startsWith('=== Source Location Trace') ||
          trimmed.startsWith('---') ||
          trimmed.startsWith('pid:') ||
          trimmed.startsWith('cwd:') ||
          trimmed.startsWith('last_command:')) {
        continue;
      }
      kept.add(line);
    }

    s = kept.join('\n').trim();
    return s;
  }

  /// Active sessions by session ID
  final Map<int, SessionContext> _sessions = {};

  /// Maximum cached sessions (prevents memory bloat)
  static const int _maxCachedSessions = 3;

  /// Get or create session context
  SessionContext getOrCreateSession({
    required int sessionId,
    required int grade,
    required String subject,
  }) {
    if (_sessions.containsKey(sessionId)) {
      final session = _sessions[sessionId]!;
      // If grade/subject changed for this session ID, recreate to prevent context bleeding.
      if (session.grade != grade || session.subject != subject) {
        debugPrint('MemoryManager: Session $sessionId grade/subject mismatch — recreating. '
            'Was: Grade ${session.grade} ${session.subject}, Now: Grade $grade $subject');
        _sessions.remove(sessionId);
      } else {
        session.touch();
        return session;
      }
    }

    // Evict oldest session if at capacity
    if (_sessions.length >= _maxCachedSessions) {
      _evictOldestSession();
    }

    final session = SessionContext(
      sessionId: sessionId,
      grade: grade,
      subject: subject,
    );
    _sessions[sessionId] = session;
    return session;
  }

  /// Clear specific session (for new chat)
  void clearSession(int sessionId) {
    _sessions.remove(sessionId);
    debugPrint('MemoryManager: Cleared session $sessionId');
  }

  /// Clear all sessions except the specified one (prevents context bleeding)
  void isolateSession(int keepSessionId) {
    final keysToRemove = _sessions.keys.where((k) => k != keepSessionId).toList();
    for (final key in keysToRemove) {
      _sessions.remove(key);
    }
    if (keysToRemove.isNotEmpty) {
      debugPrint('MemoryManager: Isolated session $keepSessionId, cleared ${keysToRemove.length} others');
    }
  }

  /// Clear all sessions
  void clearAllSessions() {
    _sessions.clear();
    debugPrint('MemoryManager: Cleared all sessions');
  }

  void _evictOldestSession() {
    if (_sessions.isEmpty) return;

    final oldest = _sessions.entries.reduce(
      (a, b) => a.value.lastAccessedAt.isBefore(b.value.lastAccessedAt) ? a : b,
    );
    _sessions.remove(oldest.key);
    debugPrint('MemoryManager: Evicted oldest session ${oldest.key}');
  }

  /// Add a message to session working memory
  void addMessage({
    required int sessionId,
    required ChatHistoryMessage message,
    required int grade,
    required String subject,
  }) {
    final session = getOrCreateSession(
      sessionId: sessionId,
      grade: grade,
      subject: subject,
    );

    session.messageCount++;

    if (message.role == 'user') {
      // Start new turn with user message
      session.workingMemory.add(ConversationTurn(userMessage: message));
    } else if (message.role == 'assistant' && session.workingMemory.isNotEmpty) {
      // Complete the last turn with assistant response
      final lastTurn = session.workingMemory.last;
      if (lastTurn.assistantMessage == null) {
        // Create new turn with updated assistant message
        session.workingMemory.removeLast();
        session.workingMemory.add(ConversationTurn(
          userMessage: lastTurn.userMessage,
          assistantMessage: message,
          timestamp: lastTurn.timestamp,
        ));
      }
    }

    // Trim working memory if exceeds limit
    while (session.workingMemory.length > _config.maxWorkingMemoryTurns) {
      final evicted = session.workingMemory.removeFirst();
      _incorporateIntoSummary(session, evicted);
    }

    // Invalidate KV cache when context changes significantly
    if (session.messageCount > _config.summarizationThreshold) {
      session.invalidateKvCache();
    }
  }

  /// Incorporate evicted turn into context summary
  void _incorporateIntoSummary(SessionContext session, ConversationTurn turn) {
    // Extract key information from the turn
    final userContent = _truncateAtSentence(
      turn.userMessage.content,
      maxChars: 100,
    );
    final assistantContent = turn.assistantMessage != null
        ? _truncateAtSentence(turn.assistantMessage!.content, maxChars: 150)
        : '';

    // Build or update summary
    final newInfo = 'Q: $userContent${assistantContent.isNotEmpty ? ' A: $assistantContent' : ''}';

    if (session.contextSummary == null) {
      session.contextSummary = 'Previous discussion: $newInfo';
    } else {
      // Append to existing summary, but keep within limits
      var updated = '${session.contextSummary} | $newInfo';
      if (updated.length > _config.maxSummaryChars) {
        // Truncate from the beginning (keep most recent context)
        updated = updated.substring(updated.length - _config.maxSummaryChars);
        // Clean up truncation (start from sentence/phrase boundary)
        final pipeIndex = updated.indexOf(' | ');
        if (pipeIndex > 0 && pipeIndex < 50) {
          updated = 'Previous discussion: ${updated.substring(pipeIndex + 3)}';
        }
      }
      session.contextSummary = updated;
    }
  }

  /// Build optimized prompt with context
  ///
  /// Uses "primacy-recency" pattern to avoid "lost in middle" problem:
  /// - System prompt at START (high attention)
  /// - Summary context in MIDDLE (compressed, less critical)
  /// - Recent working memory at END (high attention)
  String buildPromptWithContext({
    required int sessionId,
    required int grade,
    required String subject,
    required String systemPrompt,
    required String userMessage,
    List<ChatHistoryMessage>? dbHistory,
  }) {
    final session = getOrCreateSession(
      sessionId: sessionId,
      grade: grade,
      subject: subject,
    );

    session.touch();

    final buffer = StringBuffer();

    // 1. SYSTEM PROMPT (START - high attention zone)
    // AGGRESSIVE truncation for fast prefill on Class 7 devices
    var truncatedSystem = systemPrompt;
    final maxSystemChars = _config.maxPromptChars ~/ 2; // Half of total budget
    if (truncatedSystem.length > maxSystemChars) {
      truncatedSystem = _truncateAtSentence(truncatedSystem, maxChars: maxSystemChars);
    }
    buffer.writeln(truncatedSystem);
    buffer.writeln();

    // 2. CONTEXT SUMMARY (MIDDLE - lower attention, but compressed)
    if (session.contextSummary != null && session.contextSummary!.isNotEmpty) {
      buffer.writeln('[Context: ${session.contextSummary}]');
      buffer.writeln();
    }

    // 3. WORKING MEMORY / DB HISTORY (END - high attention zone)
    // If we have DB history but no working memory, rebuild from DB
    if (session.workingMemory.isEmpty && dbHistory != null && dbHistory.isNotEmpty) {
      _rebuildWorkingMemoryFromDb(session, dbHistory);
    }

    // Add working memory turns
    for (final turn in session.workingMemory) {
      final userContent = _truncateAtSentence(
        _sanitizeForPrompt(turn.userMessage.content),
        maxChars: _config.maxMessageChars,
      );
      if (userContent.isNotEmpty) {
        buffer.writeln('Student: $userContent');
      }

      if (turn.assistantMessage != null) {
        final assistantContent = _truncateAtSentence(
          _sanitizeForPrompt(turn.assistantMessage!.content),
          maxChars: _config.maxMessageChars,
        );
        if (assistantContent.isNotEmpty) {
          buffer.writeln('Teacher: $assistantContent');
        }
      }
      buffer.writeln();
    }

    // 4. CURRENT USER MESSAGE (END - highest attention)
    var truncatedUser = _sanitizeForPrompt(userMessage).trim();
    if (truncatedUser.length > _config.maxMessageChars) {
      truncatedUser = _truncateAtSentence(truncatedUser, maxChars: _config.maxMessageChars);
    }
    buffer.write('Student: $truncatedUser\n\nTeacher:');

    var prompt = buffer.toString();

    // Final length check with recursive reduction
    if (prompt.length > _config.maxPromptChars) {
      prompt = _reducePromptLength(prompt, session, systemPrompt, userMessage);
    }

    debugPrint('MemoryManager: Built prompt (${prompt.length} chars, '
        '${session.workingMemory.length} turns in memory, '
        'summary: ${session.contextSummary?.length ?? 0} chars)');

    return prompt;
  }

  /// Rebuild working memory from database history
  void _rebuildWorkingMemoryFromDb(SessionContext session, List<ChatHistoryMessage> dbHistory) {
    session.workingMemory.clear();

    // Take last N*2 messages (N turns = N user + N assistant)
    final maxMessages = _config.maxWorkingMemoryTurns * 2;
    final recent = dbHistory.length > maxMessages
        ? dbHistory.sublist(dbHistory.length - maxMessages)
        : dbHistory;

    // Summarize older messages if we have them
    if (dbHistory.length > maxMessages) {
      final older = dbHistory.sublist(0, dbHistory.length - maxMessages);
      _buildSummaryFromHistory(session, older);
    }

    // Pair messages into turns
    ChatHistoryMessage? pendingUser;
    for (final msg in recent) {
      if (msg.role == 'user') {
        if (pendingUser != null) {
          // Previous user message had no response
          session.workingMemory.add(ConversationTurn(userMessage: pendingUser));
        }
        pendingUser = msg;
      } else if (msg.role == 'assistant' && pendingUser != null) {
        session.workingMemory.add(ConversationTurn(
          userMessage: pendingUser,
          assistantMessage: msg,
        ));
        pendingUser = null;
      }
    }

    // Don't forget trailing user message
    if (pendingUser != null) {
      session.workingMemory.add(ConversationTurn(userMessage: pendingUser));
    }

    debugPrint('MemoryManager: Rebuilt working memory from DB '
        '(${session.workingMemory.length} turns from ${dbHistory.length} messages)');
  }

  /// Build summary from older history messages
  void _buildSummaryFromHistory(SessionContext session, List<ChatHistoryMessage> older) {
    if (older.isEmpty) return;

    final parts = <String>[];
    for (var i = 0; i < older.length; i += 2) {
      final userMsg = older[i];
      final assistantMsg = i + 1 < older.length ? older[i + 1] : null;

      if (userMsg.role == 'user') {
        final q = _truncateAtSentence(userMsg.content, maxChars: 80);
        final a = assistantMsg?.role == 'assistant'
            ? _truncateAtSentence(assistantMsg!.content, maxChars: 100)
            : '';
        parts.add('Q: $q${a.isNotEmpty ? ' A: $a' : ''}');
      }
    }

    if (parts.isNotEmpty) {
      var summary = 'Previous discussion: ${parts.join(' | ')}';
      if (summary.length > _config.maxSummaryChars) {
        summary = summary.substring(0, _config.maxSummaryChars);
        // Clean up at word boundary
        final lastSpace = summary.lastIndexOf(' ');
        if (lastSpace > _config.maxSummaryChars - 50) {
          summary = '${summary.substring(0, lastSpace)}...';
        }
      }
      session.contextSummary = summary;
    }
  }

  /// Reduce prompt length while preserving critical information
  String _reducePromptLength(
    String prompt,
    SessionContext session,
    String systemPrompt,
    String userMessage,
  ) {
    // Strategy 1: Drop context summary
    if (session.contextSummary != null) {
      session.contextSummary = null;
      return buildPromptWithContext(
        sessionId: session.sessionId,
        grade: session.grade,
        subject: session.subject,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );
    }

    // Strategy 2: Reduce working memory
    if (session.workingMemory.length > 2) {
      while (session.workingMemory.length > 2) {
        session.workingMemory.removeFirst();
      }
      return buildPromptWithContext(
        sessionId: session.sessionId,
        grade: session.grade,
        subject: session.subject,
        systemPrompt: systemPrompt,
        userMessage: userMessage,
      );
    }

    // Strategy 3: Hard truncate
    return prompt.substring(0, _config.maxPromptChars);
  }

  /// Truncate text at sentence boundary (smarter than mid-word cut)
  String _truncateAtSentence(String text, {required int maxChars}) {
    if (text.length <= maxChars) return text;

    if (!_config.useSentenceBoundary) {
      return '${text.substring(0, maxChars)}...';
    }

    // Find sentence boundary near max length
    var cutoff = maxChars;

    // Look for sentence enders
    final sentenceEnders = ['. ', '! ', '? ', '।', '\n'];
    var bestCut = -1;

    for (final ender in sentenceEnders) {
      var searchStart = (maxChars * 0.6).toInt(); // Look in last 40%
      while (true) {
        final idx = text.indexOf(ender, searchStart);
        if (idx == -1 || idx > maxChars) break;
        bestCut = idx + ender.length;
        searchStart = idx + 1;
      }
    }

    if (bestCut > maxChars * 0.5) {
      cutoff = bestCut;
    } else {
      // Fall back to word boundary
      final lastSpace = text.lastIndexOf(' ', maxChars);
      if (lastSpace > maxChars * 0.7) {
        cutoff = lastSpace;
      }
    }

    return '${text.substring(0, cutoff).trimRight()}...';
  }

  /// Check if session needs context rebuild (e.g., after app restart)
  bool needsContextRebuild(int sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return true;
    return session.workingMemory.isEmpty && !session.kvCacheValid;
  }

  /// Check if KV cache is valid for a session
  bool isKvCacheValid(int sessionId) {
    return _sessions[sessionId]?.kvCacheValid ?? false;
  }

  /// Mark KV cache as valid
  void markKvCacheValid(int sessionId) {
    _sessions[sessionId]?.markKvCacheValid();
  }

  /// Invalidate KV cache (e.g., when editing messages)
  void invalidateKvCache(int sessionId) {
    _sessions[sessionId]?.invalidateKvCache();
  }

  /// Get session info for debugging
  Map<String, dynamic>? getSessionInfo(int sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return null;

    return {
      'uuid': session.uuid,
      'grade': session.grade,
      'subject': session.subject,
      'messageCount': session.messageCount,
      'workingMemoryTurns': session.workingMemory.length,
      'hasSummary': session.contextSummary != null,
      'summaryLength': session.contextSummary?.length ?? 0,
      'kvCacheValid': session.kvCacheValid,
      'createdAt': session.createdAt.toIso8601String(),
      'lastAccessedAt': session.lastAccessedAt.toIso8601String(),
    };
  }

  /// Update config (e.g., for device RAM changes)
  void updateConfig(MemoryConfig newConfig) {
    // Note: Can't change _config directly as it's final
    // In practice, create a new manager with new config
    debugPrint('MemoryManager: Config update requested '
        '(maxWorkingMemoryTurns: ${newConfig.maxWorkingMemoryTurns}, '
        'maxPromptChars: ${newConfig.maxPromptChars})');
  }
}
