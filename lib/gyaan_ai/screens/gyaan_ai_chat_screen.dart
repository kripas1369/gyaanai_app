import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../services/hybrid_ai_service.dart'; // exports ChatHistoryMessage
import '../services/gyaan_ai_system_prompt.dart';
import '../services/translation_service.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/scaffold_with_banner.dart';

class GyaanAiChatScreen extends ConsumerStatefulWidget {
  const GyaanAiChatScreen({
    super.key,
    required this.grade,
    required this.subject,
    required this.sessionId,
    this.initialQuestion,
  });

  final int grade;
  final SubjectItem subject;
  final int sessionId;
  /// If set, this question is auto-sent as the first message (from Practice Questions).
  final String? initialQuestion;

  @override
  ConsumerState<GyaanAiChatScreen> createState() => _GyaanAiChatScreenState();
}

enum _AnswerLang { english, nepali }

class _GyaanAiChatScreenState extends ConsumerState<GyaanAiChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _imagePicker = ImagePicker();

  var _thinking = false;
  var _streamingAssistant = false;
  var _preparing = false;  // Shows "Preparing..." before prefill starts
  var _showSalute = false; // Brief salute animation after response completes
  List<_ChatLine> _lines = [];
  AiMode _currentMode = AiMode.offline;
  XFile? _pendingImage; // Image selected by user, not yet sent

  /// Stop streaming flag
  var _stopRequested = false;

  /// Tracks if last response was truncated (timeout/limit)
  var _lastResponseTruncated = false;

  /// How many times we have auto-continued in a row (prevents infinite loops)
  var _autoContinueCount = 0;
  static const _maxAutoContinues = 3;

  /// Assistant bubbles: English from the model; Nepali is loaded on demand in the app.
  _AnswerLang _answerLang = _AnswerLang.english;
  final Map<int, String> _nepaliByMessageId = {};
  final Set<int> _nepaliLoading = {};
  final Set<int> _nepaliFailed = {};

  @override
  void initState() {
    super.initState();
    _load();
    _checkAiMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _pendingImage = picked);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Attach Image',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                'Take a photo of your textbook question',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GyaanAiColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: GyaanAiColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: GyaanAiColors.secondary),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture question'),
                onTap: () {
                  Navigator.pop(c);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from your photos'),
                onTap: () {
                  Navigator.pop(c);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkAiMode() async {
    final hybrid = ref.read(hybridAiProvider);
    final mode = await hybrid.getCurrentMode();
    if (mounted) {
      setState(() {
        _currentMode = mode;
      });
    }
  }

  @override
  void dispose() {
    // Clear this session from cache when leaving to prevent stale context
    // This ensures next time this session is opened, it gets fresh context
    ref.read(gemmaOfflineProvider).clearSession(widget.sessionId);
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gemma = ref.read(gemmaOfflineProvider);

    // CRITICAL: Invalidate session if grade/subject changed
    // This prevents context bleeding when user switches subjects
    gemma.invalidateSessionIfMismatch(
      widget.sessionId,
      widget.grade,
      widget.subject.english,
    );

    // Clear other Gemma sessions to prevent context bleeding across grade/subject
    gemma.clearOtherSessions(widget.sessionId);

    final repo = ref.read(gyaanAiChatRepoProvider);
    final rows = await repo.messagesForSession(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _lines = rows.map(_ChatLine.fromDb).toList();
    });
    _scrollToBottom();
    _prefetchNepaliIfNeeded();

    // Auto-send initial question from Practice Questions screen
    if (widget.initialQuestion != null && _lines.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _input.text = widget.initialQuestion!;
          _send();
        }
      });
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(max);
      } else {
        _scroll.animateTo(
          max,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _titleFromFirstMessage(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Chat';
    if (t.length <= 50) return t;
    return '${t.substring(0, 50)}…';
  }

  Future<void> _send() async {
    var text = _input.text.trim();
    final imageToSend = _pendingImage;

    // Allow sending with image even if no text
    if (text.isEmpty && imageToSend == null) return;
    if (_thinking) return;

    // Default text when only image is sent
    if (text.isEmpty && imageToSend != null) {
      text = 'Please help me solve this problem from the image.';
    }

    final repo = ref.read(gyaanAiChatRepoProvider);
    final hybridAi = ref.read(hybridAiProvider);
    final offlineSync = ref.read(offlineSyncProvider);
    final system = buildGyaanAiSystemPrompt(
      grade: widget.grade,
      subjectEnglish: widget.subject.english,
      hasImage: imageToSend != null,
    );

    final imagePath = imageToSend?.path;
    // Read image bytes BEFORE we null out _pendingImage in setState below.
    // Gemma 4 E2B is multimodal — these bytes go straight into Message.withImage.
    Uint8List? imageBytes;
    if (imageToSend != null) {
      try {
        imageBytes = await imageToSend.readAsBytes();
      } catch (e) {
        debugPrint('ChatScreen: Failed to read image bytes: $e');
      }
    }
    // Reset auto-continue counter only when user sends a brand-new question
    final isContinuation = text.trim().toLowerCase() == 'continue';
    if (!isContinuation) _autoContinueCount = 0;

    setState(() {
      _thinking = true;
      _preparing = true;
      _streamingAssistant = false;
      _lastResponseTruncated = false;
      _pendingImage = null;
    });
    _input.clear();

    // CRITICAL: Let UI fully render BEFORE starting heavy AI prefill.
    // The prefill phase blocks Dart's event loop (native LLM operation),
    // so we need to ensure the "Preparing..." indicator is visible first.
    // Use endOfFrame to guarantee the frame painted, then yield microtasks.
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(Duration.zero); // Yield to pending microtasks

    try {
      await repo.insertUserMessage(widget.sessionId, text);

      final rows = await repo.messagesForSession(widget.sessionId);
      if (rows.length == 1) {
        await repo.updateSessionTitle(
          widget.sessionId,
          _titleFromFirstMessage(text),
        );
      }

      if (!mounted) return;
      setState(() {
        _lines = _buildLinesFromRows(rows, lastUserImagePath: imagePath);
      });
      _scrollToBottom();

      var fullAnswer = '';
      var lastUiAt = DateTime.fromMillisecondsSinceEpoch(0);
      var lastPainted = '';
      const streamUiInterval = Duration(milliseconds: 25);

      // Build conversation history for context-aware responses
      final history = rows.map((row) => ChatHistoryMessage(
        role: row['role'] as String,
        content: row['content'] as String,
        timestamp: DateTime.parse(row['created_at'] as String),
      )).toList();

      await for (final assembled in hybridAi.runInferenceStreaming(
        grade: widget.grade,
        subjectEnglish: widget.subject.english,
        userMessage: text,
        systemPrompt: system,
        sessionId: widget.sessionId,
        history: history,
        imageBytes: imageBytes,
      )) {
        if (_stopRequested) break;

        fullAnswer = assembled;
        if (!mounted) return;
        final now = DateTime.now();
        if (now.difference(lastUiAt) < streamUiInterval) continue;
        lastUiAt = now;
        lastPainted = assembled;
        setState(() {
          _preparing = false;
          _streamingAssistant = true;
          _lines = [
            ..._buildLinesFromRows(rows, lastUserImagePath: imagePath),
            _ChatLine(
              dbId: null,
              role: 'assistant',
              content: assembled,
              createdAt: DateTime.now(),
              streaming: true,
            ),
          ];
        });
        _scrollToBottom(jump: true);
      }
      if (mounted && fullAnswer != lastPainted) {
        setState(() {
          _streamingAssistant = true;
          _lines = [
            ..._buildLinesFromRows(rows, lastUserImagePath: imagePath),
            _ChatLine(
              dbId: null,
              role: 'assistant',
              content: fullAnswer,
              createdAt: DateTime.now(),
              streaming: true,
            ),
          ];
        });
        _scrollToBottom(jump: true);
      }

      // Check if response was truncated (contains truncation markers)
      final wasTruncated = fullAnswer.contains('truncated due to') ||
          fullAnswer.contains('timed out') ||
          fullAnswer.contains('stalled') ||
          _stopRequested;

      await repo.insertAssistantMessage(widget.sessionId, fullAnswer);

      // Queue for sync if we were offline
      if (_currentMode == AiMode.offline) {
        await offlineSync.queueChatMessage(
          sessionId: widget.sessionId,
          role: 'user',
          content: text,
          createdAt: DateTime.now(),
        );
        await offlineSync.queueChatMessage(
          sessionId: widget.sessionId,
          role: 'assistant',
          content: fullAnswer,
          createdAt: DateTime.now(),
        );
      }

      await _load();

      // Set truncation flag after load to show Continue button
      if (mounted && wasTruncated) {
        setState(() {
          _lastResponseTruncated = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        final wasStopped = _stopRequested;
        setState(() {
          _thinking = false;
          _preparing = false;
          _streamingAssistant = false;
          _stopRequested = false;
          _showSalute = !_lastResponseTruncated;
        });

        // Stop ⇒ KV cache holds a half-finished assistant turn. If we leave it,
        // the next user message takes the fast path and the model continues
        // the abandoned reply instead of answering the new question.
        if (wasStopped) {
          ref.read(gemmaOfflineProvider).abortGeneration(widget.sessionId);
        }

        // Auto-continue if truncated and user did not manually stop
        if (_lastResponseTruncated && !wasStopped && _autoContinueCount < _maxAutoContinues) {
          _autoContinueCount++;
          // Brief delay so the UI can settle before continuing
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) await _continueResponse();
        } else if (!_lastResponseTruncated) {
          _autoContinueCount = 0; // Reset counter on clean finish
        }
      }
    }
  }

  void _dismissSalute() {
    if (mounted) setState(() => _showSalute = false);
  }

  void _togglePause() {
    setState(() {
      _stopRequested = true;
      _autoContinueCount = _maxAutoContinues; // Prevent auto-continue after manual stop
    });
  }

  /// Continue a truncated response by sending a continuation request
  Future<void> _continueResponse() async {
    if (_thinking) return;

    setState(() {
      _lastResponseTruncated = false;
    });

    _input.text = 'continue';
    await _send();
  }

  Future<void> _newChat() async {
    final repo = ref.read(gyaanAiChatRepoProvider);
    final gemma = ref.read(gemmaOfflineProvider);

    // CRITICAL: Clear ALL sessions to ensure fresh context for new chat
    // This prevents any context bleeding from previous conversations
    gemma.clearAllSessions();

    final id = await repo.createEmptySession(
      grade: widget.grade,
      subjectKey: widget.subject.key,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideFromRight(
        GyaanAiChatScreen(
          grade: widget.grade,
          subject: widget.subject,
          sessionId: id,
        ),
      ),
    );
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This removes all messages in this session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.clearMessages(widget.sessionId);
    await repo.updateSessionTitle(widget.sessionId, 'New chat');
    // Clear the Gemma conversation session cache for this chat
    ref.read(gemmaOfflineProvider).clearSession(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _nepaliByMessageId.clear();
      _nepaliLoading.clear();
      _nepaliFailed.clear();
    });
    await _load();
  }

  void _goHistory() {
    Navigator.of(context).pop();
  }

  Future<void> _editMessage(_ChatLine line) async {
    if (line.dbId == null) return;
    final controller = TextEditingController(text: line.content);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Edit your message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty || result == line.content) return;

    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.updateMessage(line.dbId!, result);
    await _load();
  }

  Future<void> _deleteMessage(_ChatLine line) async {
    if (line.dbId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.deleteMessage(line.dbId!);
    await _load();
  }

  Future<void> _copyMessage(_ChatLine line) async {
    await Clipboard.setData(ClipboardData(text: line.content));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _regenerateResponse(_ChatLine line) async {
    if (line.role != 'assistant' || line.dbId == null || _thinking) return;

    // Find the user message before this assistant response
    final idx = _lines.indexWhere((l) => l.dbId == line.dbId);
    if (idx <= 0) return;
    final userLine = _lines[idx - 1];
    if (userLine.role != 'user') return;

    HapticFeedback.mediumImpact();

    // Delete the current assistant response
    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.deleteMessage(line.dbId!);

    // Re-run inference with the same user message
    setState(() {
      _thinking = true;
      _streamingAssistant = false;
    });

    try {
      final hybridAi = ref.read(hybridAiProvider);
      final system = buildGyaanAiSystemPrompt(
        grade: widget.grade,
        subjectEnglish: widget.subject.english,
      );

      final rows = await repo.messagesForSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _lines = rows.map(_ChatLine.fromDb).toList();
      });

      var fullAnswer = '';
      var lastUiAt = DateTime.fromMillisecondsSinceEpoch(0);
      var lastPainted = '';
      const streamUiInterval = Duration(milliseconds: 25);

      final history = rows.map((row) => ChatHistoryMessage(
        role: row['role'] as String,
        content: row['content'] as String,
        timestamp: DateTime.parse(row['created_at'] as String),
      )).toList();

      await for (final assembled in hybridAi.runInferenceStreaming(
        grade: widget.grade,
        subjectEnglish: widget.subject.english,
        userMessage: userLine.content,
        systemPrompt: system,
        sessionId: widget.sessionId,
        history: history,
      )) {
        if (_stopRequested) break;
        fullAnswer = assembled;
        if (!mounted) return;
        final now = DateTime.now();
        if (now.difference(lastUiAt) < streamUiInterval) continue;
        lastUiAt = now;
        lastPainted = assembled;
        setState(() {
          _streamingAssistant = true;
          _lines = [
            ...rows.map(_ChatLine.fromDb),
            _ChatLine(
              dbId: null,
              role: 'assistant',
              content: assembled,
              createdAt: DateTime.now(),
              streaming: true,
            ),
          ];
        });
        _scrollToBottom(jump: true);
      }
      if (mounted && fullAnswer != lastPainted) {
        setState(() {
          _lines = [
            ...rows.map(_ChatLine.fromDb),
            _ChatLine(
              dbId: null,
              role: 'assistant',
              content: fullAnswer,
              createdAt: DateTime.now(),
              streaming: true,
            ),
          ];
        });
      }

      await repo.insertAssistantMessage(widget.sessionId, fullAnswer);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Regenerate failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _thinking = false;
          _streamingAssistant = false;
          _stopRequested = false;
          _showSalute = true; // Trigger salute animation
        });
      }
    }
  }

  void _showMessageOptions(_ChatLine line) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Copy option for all messages
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: GyaanAiColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.copy_rounded, color: GyaanAiColors.secondary),
                ),
                title: const Text('Copy'),
                subtitle: const Text('Copy message to clipboard'),
                onTap: () {
                  Navigator.pop(c);
                  _copyMessage(line);
                },
              ),
              // Regenerate for assistant messages
              if (line.role == 'assistant')
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.blue),
                  ),
                  title: const Text('Regenerate'),
                  subtitle: const Text('Get a new response'),
                  onTap: () {
                    Navigator.pop(c);
                    _regenerateResponse(line);
                  },
                ),
              // Edit for user messages
              if (line.role == 'user')
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: GyaanAiColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded, color: GyaanAiColors.accent),
                  ),
                  title: const Text('Edit'),
                  subtitle: const Text('Modify your message'),
                  onTap: () {
                    Navigator.pop(c);
                    _editMessage(line);
                  },
                ),
              // Delete for all messages
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Remove this message'),
                onTap: () {
                  Navigator.pop(c);
                  _deleteMessage(line);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds chat lines from DB rows, injecting `imagePath` into the last user message.
  List<_ChatLine> _buildLinesFromRows(
    List<Map<String, Object?>> rows, {
    String? lastUserImagePath,
  }) {
    final lines = rows.map(_ChatLine.fromDb).toList();
    if (lastUserImagePath != null) {
      for (var i = lines.length - 1; i >= 0; i--) {
        if (lines[i].role == 'user') {
          final l = lines[i];
          lines[i] = _ChatLine(
            dbId: l.dbId,
            role: l.role,
            content: l.content,
            createdAt: l.createdAt,
            imagePath: lastUserImagePath,
          );
          break;
        }
      }
    }
    return lines;
  }

  void _prefetchNepaliIfNeeded() {
    if (_answerLang != _AnswerLang.nepali) return;
    for (final line in _lines) {
      if (line.role == 'assistant' && line.dbId != null && !line.streaming) {
        unawaited(_fetchNepaliIfNeeded(line));
      }
    }
  }

  Future<void> _fetchNepaliIfNeeded(_ChatLine line) async {
    final id = line.dbId;
    if (id == null || line.role != 'assistant' || line.streaming) return;
    if (_nepaliByMessageId.containsKey(id) ||
        _nepaliLoading.contains(id) ||
        _nepaliFailed.contains(id)) {
      return;
    }
    final source = line.content.trim();
    if (source.isEmpty) return;

    setState(() => _nepaliLoading.add(id));

    // Use fast package-based translation instead of AI
    try {
      final translated = await TranslationService.instance.toNepali(source);
      final out = translated.trim();
      if (!mounted) return;
      setState(() {
        _nepaliLoading.remove(id);
        if (out.isEmpty) {
          _nepaliFailed.add(id);
        } else {
          _nepaliByMessageId[id] = out;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nepaliLoading.remove(id);
        _nepaliFailed.add(id);
      });
    }
  }

  void _onToggleAnswerLanguage() {
    final next =
        _answerLang == _AnswerLang.english ? _AnswerLang.nepali : _AnswerLang.english;
    setState(() {
      _answerLang = next;
      if (next == _AnswerLang.nepali) {
        _nepaliFailed.clear();
      }
    });
    if (next == _AnswerLang.nepali) {
      for (final line in _lines) {
        if (line.role == 'assistant' && line.dbId != null && !line.streaming) {
          unawaited(_fetchNepaliIfNeeded(line));
        }
      }
    }
  }

  Widget _buildAssistantMessageBody(_ChatLine line, BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: GyaanAiColors.textPrimary,
        );
    if (_answerLang == _AnswerLang.english || line.dbId == null) {
      return _SafeMarkdown(data: line.content, style: baseStyle);
    }
    final id = line.dbId!;
    if (_nepaliByMessageId.containsKey(id)) {
      return _SafeMarkdown(
        data: _nepaliByMessageId[id]!,
        style: baseStyle,
      );
    }
    if (_nepaliLoading.contains(id)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GyaanAiColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading Nepali…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GyaanAiColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SafeMarkdown(data: line.content, style: baseStyle),
        ],
      );
    }
    if (_nepaliFailed.contains(id)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SafeMarkdown(data: line.content, style: baseStyle),
          const SizedBox(height: 8),
          Text(
            'Nepali view unavailable. Check connection or try again.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: GyaanAiColors.textSecondary,
                ),
          ),
        ],
      );
    }
    return _SafeMarkdown(data: line.content, style: baseStyle);
  }

  Widget _buildEmptyState(BuildContext context) {
    final suggestions = getSubjectSuggestions(widget.grade, widget.subject.key);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: GyaanAiColors.gradientPrimary,
                shape: BoxShape.circle,
                boxShadow: GyaanAiShadows.coloredShadow(GyaanAiColors.primary),
              ),
              child: Center(
                child: Text(
                  widget.subject.emoji,
                  style: const TextStyle(fontSize: 38),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.grade == 0 ? 'GyaanAi Assistant' : widget.subject.nepali,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: GyaanAiColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.grade == 0
                  ? 'Ask me anything!'
                  : 'Class ${widget.grade} • ${widget.subject.english}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GyaanAiColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            // Multimodal hero card — surfaces the Gemma 4 vision capability.
            // This is the Snap-&-Solve moneyshot for the demo; do not remove
            // without updating the empty-state narrative.
            GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GyaanAiColors.primary.withValues(alpha: 0.08),
                      GyaanAiColors.secondary.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GyaanAiColors.secondary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: GyaanAiColors.gradientPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Snap & Solve',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: GyaanAiColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: GyaanAiColors.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Photograph a textbook problem — works fully offline',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: GyaanAiColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: GyaanAiColors.secondary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Try asking:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: GyaanAiColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((q) {
                return GestureDetector(
                  onTap: () {
                    _input.text = q;
                    _focus.requestFocus();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: GyaanAiColors.secondary.withValues(alpha: 0.25),
                      ),
                      boxShadow: GyaanAiShadows.card,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 14,
                          color: GyaanAiColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            q,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: GyaanAiColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pendingImage == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GyaanAiColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GyaanAiColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_pendingImage!.path),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image attached',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: GyaanAiColors.secondary,
                      ),
                ),
                Text(
                  'AI will analyze this image',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: GyaanAiColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _pendingImage = null),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: GyaanAiColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('h:mm a');
    final showTyping = _thinking && !_streamingAssistant;
    final showAnimation = showTyping || _showSalute;
    final showContinueButton = _lastResponseTruncated && !_thinking;
    final isEmpty = _lines.isEmpty && !showAnimation;

    return ScaffoldWithBanner(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.grade == 0
                  ? 'General AI'
                  : '${widget.subject.english} — Class ${widget.grade}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            // AI mode indicator - shows Online or Offline
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _currentMode == AiMode.online
                        ? Colors.green
                        : GyaanAiColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentMode == AiMode.online ? 'Online' : 'Offline AI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _currentMode == AiMode.online
                            ? Colors.green
                            : GyaanAiColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _currentMode == AiMode.online
                      ? Icons.cloud_done_rounded
                      : Icons.offline_bolt_rounded,
                  size: 12,
                  color: (_currentMode == AiMode.online
                          ? Colors.green
                          : GyaanAiColors.secondary)
                      .withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _answerLang == _AnswerLang.english
                ? 'Show answers in Nepali'
                : 'Show answers in English',
            onPressed: _onToggleAnswerLanguage,
            icon: Icon(
              Icons.translate_rounded,
              color: _answerLang == _AnswerLang.nepali
                  ? GyaanAiColors.secondary
                  : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'new':
                  _newChat();
                  break;
                case 'clear':
                  _clearChat();
                  break;
                case 'history':
                  _goHistory();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new', child: Text('New Chat')),
              PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
              PopupMenuItem(value: 'history', child: Text('Chat History')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _lines.length + (showAnimation ? 1 : 0) + (showContinueButton ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showContinueButton && i == _lines.length) {
                        return _ContinueButton(onPressed: _continueResponse);
                      }
                      final animationIndex = showContinueButton ? _lines.length + 1 : _lines.length;
                      if (showAnimation && i == animationIndex) {
                        if (_showSalute) {
                          return _SaluteAnimation(onComplete: _dismissSalute);
                        }
                        return _TypingBlock(preparing: _preparing);
                      }
                      final line = _lines[i];
                      final isUser = line.role == 'user';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.86,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: isUser
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isUser) ...[
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Text('🍃', style: TextStyle(fontSize: 14)),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: GestureDetector(
                                        onLongPress: line.streaming || line.dbId == null
                                            ? null
                                            : () => _showMessageOptions(line),
                                        child: RepaintBoundary(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? GyaanAiColors.bubbleUser
                                                  : GyaanAiColors.bubbleAi,
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(16),
                                                topRight: const Radius.circular(16),
                                                bottomLeft: Radius.circular(isUser ? 16 : 4),
                                                bottomRight: Radius.circular(isUser ? 4 : 16),
                                              ),
                                              border: isUser
                                                  ? null
                                                  : Border.all(
                                                      color: Colors.black.withValues(alpha: 0.06),
                                                    ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: isUser
                                                  ? Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (line.imagePath != null) ...[
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.file(
                                                              File(line.imagePath!),
                                                              width: double.infinity,
                                                              height: 180,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 8),
                                                        ],
                                                        Text(
                                                          line.content,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                  color: GyaanAiColors.textPrimary),
                                                        ),
                                                      ],
                                                    )
                                                  : (line.streaming
                                                      ? _AnimatedStreamingText(
                                                          text: line.content,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                color: GyaanAiColors.textPrimary,
                                                              ),
                                                        )
                                                      : _buildAssistantMessageBody(line, context)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  df.format(line.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: GyaanAiColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Image preview strip
          _buildImagePreview(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: _pendingImage != null
                        ? GyaanAiColors.secondary.withValues(alpha: 0.4)
                        : GyaanAiColors.secondary.withValues(alpha: 0.12),
                    width: _pendingImage != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Camera / image attach button
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 6),
                      child: IconButton(
                        onPressed: _thinking ? null : _showImageSourceSheet,
                        icon: Icon(
                          _pendingImage != null
                              ? Icons.image_rounded
                              : Icons.add_photo_alternate_rounded,
                          color: _pendingImage != null
                              ? GyaanAiColors.secondary
                              : GyaanAiColors.textHint,
                        ),
                        tooltip: 'Attach image',
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: _pendingImage != null
                              ? 'Add a question about this image...'
                              : 'Type your question... / आफ्नो प्रश्न...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // Show stop button during streaming, send button otherwise
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: _streamingAssistant
                          ? _StopGeneratingButton(onPressed: _togglePause)
                          : ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _input,
                              builder: (context, value, _) {
                                final hasContent = value.text.trim().isNotEmpty || _pendingImage != null;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: hasContent && !_thinking
                                        ? GyaanAiColors.gradientPrimary
                                        : null,
                                    color: hasContent && !_thinking
                                        ? null
                                        : Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: (_thinking || !hasContent) ? null : _send,
                                    icon: Icon(
                                      Icons.send_rounded,
                                      size: 20,
                                      color: hasContent && !_thinking
                                          ? Colors.white
                                          : Colors.grey.shade400,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLine {
  _ChatLine({
    required this.dbId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.streaming = false,
    this.imagePath,
  });

  final int? dbId;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool streaming;
  final String? imagePath;

  static _ChatLine fromDb(Map<String, Object?> m) {
    return _ChatLine(
      dbId: m['id'] as int,
      role: m['role'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

/// Continue button shown when AI response was truncated
/// Styled like ChatGPT/Claude's continue generation button
class _ContinueButton extends StatefulWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            // Subtle glow pulse
            final glowOpacity = 0.15 + (_pulseAnimation.value * 0.15);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: GyaanAiColors.secondary.withValues(alpha: glowOpacity),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2D2D2D)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? GyaanAiColors.secondary.withValues(alpha: 0.4)
                        : GyaanAiColors.secondary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GyaanAiColors.secondary,
                            GyaanAiColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Continue generating',
                      style: TextStyle(
                        color: isDark ? Colors.white : GyaanAiColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stop generating button - ChatGPT/Claude style
/// Shows during AI response streaming to allow user to stop generation
class _StopGeneratingButton extends StatefulWidget {
  const _StopGeneratingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StopGeneratingButton> createState() => _StopGeneratingButtonState();
}

class _StopGeneratingButtonState extends State<_StopGeneratingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          // Subtle breathing effect
          final scale = 1.0 + (_pulseController.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3D3D3D)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Square stop icon (ChatGPT style)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF424242),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stop',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFF424242),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingBlock extends StatefulWidget {
  const _TypingBlock({this.preparing = false});

  final bool preparing;

  @override
  State<_TypingBlock> createState() => _TypingBlockState();
}

class _TypingBlockState extends State<_TypingBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 38), // Space for avatar alignment
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: GyaanAiColors.bubbleAi,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: GyaanAiColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Running man animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(32, 32),
                        painter: _RunningManPainter(
                          progress: _controller.value,
                          color: isDark
                              ? GyaanAiColors.primary
                              : GyaanAiColors.secondary,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // "Thinking" text with fade
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final opacity = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
                      return Opacity(
                        opacity: opacity,
                        child: Text(
                          'Thinking...',
                          style: TextStyle(
                            color: GyaanAiColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for animated running stick figure.
/// Smooth running cycle with arm/leg movement.
class _RunningManPainter extends CustomPainter {
  _RunningManPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Running cycle phase (0-1 maps to full stride cycle)
    final phase = progress * 2 * math.pi;

    // Body bounce (slight up/down while running)
    final bounce = math.sin(phase * 2).abs() * 2;

    // Head
    final headY = cy - 10 - bounce;
    canvas.drawCircle(Offset(cx, headY), 5, paint);

    // Body (torso)
    final bodyTop = headY + 5;
    final bodyBottom = cy + 4 - bounce * 0.5;
    canvas.drawLine(
      Offset(cx, bodyTop),
      Offset(cx, bodyBottom),
      paint,
    );

    // Arms swing opposite to legs
    final armSwing = math.sin(phase) * 25 * math.pi / 180;
    final armLength = 8.0;

    // Left arm
    final leftArmEnd = Offset(
      cx - armLength * math.cos(armSwing + 0.3),
      bodyTop + 3 + armLength * math.sin(armSwing + 0.3),
    );
    canvas.drawLine(Offset(cx, bodyTop + 3), leftArmEnd, paint);

    // Right arm (opposite phase)
    final rightArmEnd = Offset(
      cx + armLength * math.cos(-armSwing + 0.3),
      bodyTop + 3 + armLength * math.sin(-armSwing + 0.3),
    );
    canvas.drawLine(Offset(cx, bodyTop + 3), rightArmEnd, paint);

    // Legs with running motion
    final legLength = 10.0;
    final legSwing = math.sin(phase) * 35 * math.pi / 180;

    // Left leg
    final leftKnee = Offset(
      cx - 3 + legLength * 0.5 * math.sin(legSwing),
      bodyBottom + legLength * 0.6,
    );
    final leftFoot = Offset(
      cx - 4 + legLength * math.sin(legSwing),
      bodyBottom + legLength + math.cos(legSwing).abs() * 2,
    );
    canvas.drawLine(Offset(cx, bodyBottom), leftKnee, paint);
    canvas.drawLine(leftKnee, leftFoot, paint);

    // Right leg (opposite phase)
    final rightKnee = Offset(
      cx + 3 + legLength * 0.5 * math.sin(-legSwing),
      bodyBottom + legLength * 0.6,
    );
    final rightFoot = Offset(
      cx + 4 + legLength * math.sin(-legSwing),
      bodyBottom + legLength + math.cos(-legSwing).abs() * 2,
    );
    canvas.drawLine(Offset(cx, bodyBottom), rightKnee, paint);
    canvas.drawLine(rightKnee, rightFoot, paint);

    // Motion lines (speed effect)
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 3; i++) {
      final lineY = cy - 5 + i * 6;
      final linePhase = (progress + i * 0.15) % 1.0;
      final lineX = cx - 14 - linePhase * 8;
      final lineLength = 4 + (1 - linePhase) * 4;
      canvas.drawLine(
        Offset(lineX, lineY),
        Offset(lineX - lineLength, lineY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RunningManPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Salute animation widget - shown briefly when response completes.
class _SaluteAnimation extends StatefulWidget {
  const _SaluteAnimation({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_SaluteAnimation> createState() => _SaluteAnimationState();
}

class _SaluteAnimationState extends State<_SaluteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 38),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: GyaanAiColors.bubbleAi,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: GyaanAiColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(32, 32),
                    painter: _SaluteManPainter(
                      progress: _controller.value,
                      color: isDark
                          ? GyaanAiColors.primary
                          : GyaanAiColors.secondary,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for salute pose - arm raises to head.
class _SaluteManPainter extends CustomPainter {
  _SaluteManPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Standing still - no bounce
    final headY = cy - 10;

    // Head
    canvas.drawCircle(Offset(cx, headY), 5, paint);

    // Body
    final bodyTop = headY + 5;
    final bodyBottom = cy + 4;
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyBottom), paint);

    // Salute arm (right) - raises up with progress
    final saluteAngle = -math.pi / 2 * Curves.easeOutBack.transform(progress);
    final armLength = 8.0;
    final rightArmEnd = Offset(
      cx + armLength * math.cos(saluteAngle + math.pi / 4),
      bodyTop + 3 + armLength * math.sin(saluteAngle + math.pi / 4),
    );
    canvas.drawLine(Offset(cx, bodyTop + 3), rightArmEnd, paint);

    // Forearm to head for salute
    if (progress > 0.3) {
      final forearmProgress = ((progress - 0.3) / 0.7).clamp(0.0, 1.0);
      final forearmEnd = Offset(
        cx + 3,
        headY - 2 + (1 - forearmProgress) * 8,
      );
      canvas.drawLine(rightArmEnd, forearmEnd, paint);
    }

    // Left arm at side
    canvas.drawLine(
      Offset(cx, bodyTop + 3),
      Offset(cx - 6, bodyTop + 10),
      paint,
    );

    // Legs standing straight
    canvas.drawLine(
      Offset(cx, bodyBottom),
      Offset(cx - 4, bodyBottom + 12),
      paint,
    );
    canvas.drawLine(
      Offset(cx, bodyBottom),
      Offset(cx + 4, bodyBottom + 12),
      paint,
    );

    // Star burst effect when salute completes
    if (progress > 0.7) {
      final starProgress = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
      final starPaint = Paint()
        ..color = color.withValues(alpha: (1 - starProgress) * 0.6)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final dist = 8 + starProgress * 10;
        final startDist = 6.0;
        canvas.drawLine(
          Offset(
            cx + 3 + startDist * math.cos(angle),
            headY - 5 + startDist * math.sin(angle),
          ),
          Offset(
            cx + 3 + dist * math.cos(angle),
            headY - 5 + dist * math.sin(angle),
          ),
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SaluteManPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Smooth streaming text with markdown support and blinking cursor.
/// ChatGPT-style reveal with proper dark/light theming.
class _AnimatedStreamingText extends StatefulWidget {
  const _AnimatedStreamingText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<_AnimatedStreamingText> createState() => _AnimatedStreamingTextState();
}

class _AnimatedStreamingTextState extends State<_AnimatedStreamingText>
    with TickerProviderStateMixin {
  int _displayedLength = 0;
  late final AnimationController _cursorController;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _displayedLength = widget.text.length;
  }

  @override
  void didUpdateWidget(_AnimatedStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text.length > _displayedLength) {
      _animateToNewLength(widget.text.length);
    } else if (widget.text.length < _displayedLength) {
      _displayedLength = widget.text.length;
    }
  }

  void _animateToNewLength(int targetLength) async {
    if (_isAnimating) return;
    _isAnimating = true;

    while (_displayedLength < targetLength && mounted) {
      await Future.delayed(const Duration(milliseconds: 12));
      if (mounted && _displayedLength < widget.text.length) {
        setState(() {
          // Adaptive speed: faster for longer chunks
          final remaining = widget.text.length - _displayedLength;
          final step = remaining > 50 ? 4 : (remaining > 20 ? 3 : 2);
          _displayedLength = (_displayedLength + step).clamp(0, widget.text.length);
        });
      }
    }
    _isAnimating = false;
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.substring(
      0,
      _displayedLength.clamp(0, widget.text.length),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cursorColor = isDark
        ? GyaanAiColors.primary.withValues(alpha: 0.9)
        : GyaanAiColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _StreamingMarkdown(
            data: displayText,
            style: widget.style,
          ),
        ),
        // Blinking cursor
        FadeTransition(
          opacity: _cursorController,
          child: Container(
            width: 2,
            height: 18,
            margin: const EdgeInsets.only(left: 1, bottom: 2),
            decoration: BoxDecoration(
              color: cursorColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lightweight markdown for streaming - handles partial content gracefully.
/// Uses the same LaTeX-aware logic as [_SafeMarkdown] so math renders correctly
/// even while tokens are still arriving.
class _StreamingMarkdown extends StatelessWidget {
  const _StreamingMarkdown({required this.data, this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    var cleanData = data;

    // Don't render incomplete code blocks - show as plain text until closed
    final codeBlockCount = '```'.allMatches(cleanData).length;
    if (codeBlockCount.isOdd) {
      final lastIdx = cleanData.lastIndexOf('```');
      if (lastIdx >= 0) {
        cleanData = cleanData.substring(0, lastIdx) + cleanData.substring(lastIdx + 3);
      }
    }

    // Handle $ signs: render valid LaTeX, strip only orphaned trailing $
    final useLatex = _SafeMarkdown._hasValidLatex(cleanData);
    if (!useLatex && cleanData.contains('\$')) {
      cleanData = _SafeMarkdown._stripDollars(cleanData);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MarkdownBody(
      data: useLatex ? cleanData : cleanData,
      selectable: false,
      shrinkWrap: true,
      softLineBreak: true,
      builders: useLatex
          ? {
              'latex': LatexElementBuilder(
                textStyle: style,
                textScaleFactor: 1.05,
              ),
            }
          : {},
      extensionSet: useLatex
          ? md.ExtensionSet(
              [LatexBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
              [LatexInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
            )
          : md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: style,
        code: style?.copyWith(
          fontFamily: 'monospace',
          fontSize: (style?.fontSize ?? 14) * 0.9,
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: GyaanAiColors.primary.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders markdown with LaTeX when `$`-delimited expressions look well-formed,
/// otherwise strips `$` signs and renders plain markdown — avoids "Parse Error".
class _SafeMarkdown extends StatelessWidget {
  const _SafeMarkdown({required this.data, this.style});

  final String data;
  final TextStyle? style;

  /// True when every `$` has a matching close and the inner text is non-empty.
  static bool _hasValidLatex(String s) {
    if (!s.contains('\$')) return false;
    // Check $$...$$ blocks
    final block = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    // Check $...$ inline (not empty, not just whitespace)
    final inline = RegExp(r'\$([^\$\s][^\$]*?)\$');
    return block.hasMatch(s) || inline.hasMatch(s);
  }

  /// Remove malformed LaTeX `$` delimiters but preserve normal text.
  /// Only strips paired `$...$` patterns, leaves lone `$` as-is to avoid
  /// mangling currency or other uses.
  static String _stripDollars(String s) {
    // Remove $$...$$ blocks (keep inner content)
    var out = s.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    // Remove $...$ inline (keep inner content)
    out = out.replaceAllMapped(
      RegExp(r'\$([^\$\s][^\$]*?)\$'),
      (m) => m.group(1) ?? '',
    );
    // Only remove truly orphaned $ signs at end of incomplete content
    if (out.endsWith('\$') && !out.endsWith('\$\$')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final useLatex = _hasValidLatex(data);
    final display = useLatex ? data : _stripDollars(data);

    return MarkdownBody(
      data: display,
      selectable: true,
      builders: useLatex
          ? {
              'latex': LatexElementBuilder(
                textStyle: style,
                textScaleFactor: 1.05,
              ),
            }
          : {},
      extensionSet: useLatex
          ? md.ExtensionSet(
              [LatexBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
              [LatexInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
            )
          : md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet(
        p: style,
        code: style?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Colors.grey.shade200,
        ),
      ),
    );
  }
}
