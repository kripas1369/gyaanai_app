import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../providers/padh_ai_providers.dart';
import '../services/hybrid_ai_service.dart'; // exports ChatHistoryMessage
import '../services/padh_ai_system_prompt.dart';
import '../theme/padh_ai_theme.dart';
import '../widgets/padh_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';

class PadhChatScreen extends ConsumerStatefulWidget {
  const PadhChatScreen({
    super.key,
    required this.grade,
    required this.subject,
    required this.sessionId,
  });

  final int grade;
  final SubjectItem subject;
  final int sessionId;

  @override
  ConsumerState<PadhChatScreen> createState() => _PadhChatScreenState();
}

enum _AnswerLang { english, nepali }

class _PadhChatScreenState extends ConsumerState<PadhChatScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();

  var _thinking = false;
  var _streamingAssistant = false;
  List<_ChatLine> _lines = [];
  AiMode _currentMode = AiMode.offline;

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
      // Initialize model if in offline mode
      ref.read(hybridAiProvider).getCurrentMode().then((mode) {
        if (mode == AiMode.offline) {
          ref.read(gemmaOfflineProvider).loadModel().catchError((_) {});
        }
      });
      if (mounted) _focus.requestFocus();
    });
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
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(padhChatRepoProvider);
    final rows = await repo.messagesForSession(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _lines = rows.map(_ChatLine.fromDb).toList();
    });
    _scrollToBottom();
    _prefetchNepaliIfNeeded();
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
    final text = _input.text.trim();
    if (text.isEmpty || _thinking) return;

    final repo = ref.read(padhChatRepoProvider);
    final hybridAi = ref.read(hybridAiProvider);
    final offlineSync = ref.read(offlineSyncProvider);
    final system = buildPadhAiSystemPrompt(
      grade: widget.grade,
      subjectEnglish: widget.subject.english,
    );

    setState(() {
      _thinking = true;
      _streamingAssistant = false;
    });
    _input.clear();

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
        _lines = rows.map(_ChatLine.fromDb).toList();
      });
      _scrollToBottom();

      var fullAnswer = '';
      var lastUiAt = DateTime.fromMillisecondsSinceEpoch(0);
      var lastPainted = '';
      const streamUiInterval = Duration(milliseconds: 60);

      // Build conversation history for context-aware responses
      final history = rows.map((row) => ChatHistoryMessage(
        role: row['role'] as String,
        content: row['content'] as String,
        timestamp: DateTime.parse(row['created_at'] as String),
      )).toList();

      // Use hybrid AI service - automatically chooses online or offline
      // Now with session tracking and conversation history for context
      await for (final assembled in hybridAi.runInferenceStreaming(
        grade: widget.grade,
        subjectEnglish: widget.subject.english,
        userMessage: text,
        systemPrompt: system,
        sessionId: widget.sessionId,
        history: history,
      )) {
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
          _streamingAssistant = true;
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
        _scrollToBottom(jump: true);
      }

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _thinking = false;
          _streamingAssistant = false;
        });
      }
    }
  }

  Future<void> _newChat() async {
    final repo = ref.read(padhChatRepoProvider);
    final id = await repo.createEmptySession(
      grade: widget.grade,
      subjectKey: widget.subject.key,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideFromRight(
        PadhChatScreen(
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
    final repo = ref.read(padhChatRepoProvider);
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

  static const _kMaxTranslationChars = 10000;

  String _trimForTranslation(String s) {
    final t = s.trim();
    if (t.length <= _kMaxTranslationChars) return t;
    return '${t.substring(0, _kMaxTranslationChars)}\n\n[…truncated]';
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

    final hybrid = ref.read(hybridAiProvider);
    try {
      final translated = await hybrid.runInference(
        grade: widget.grade,
        subjectEnglish: widget.subject.english,
        systemPrompt: buildTutorAnswerTranslationSystemPrompt(),
        userMessage:
            'Translate the following tutor reply into Nepali (see system rules).\n\n---\n\n${_trimForTranslation(source)}',
        sessionId: null,
        history: null,
      );
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
          color: PadhAiColors.textPrimary,
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
                  color: PadhAiColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading Nepali…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: PadhAiColors.textSecondary,
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
                  color: PadhAiColors.textSecondary,
                ),
          ),
        ],
      );
    }
    return _SafeMarkdown(data: line.content, style: baseStyle);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('h:mm a');
    final showTyping = _thinking && !_streamingAssistant;

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
              '${widget.subject.english} — Class ${widget.grade}',
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
                        : PadhAiColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentMode == AiMode.online ? 'Online' : 'Offline AI',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _currentMode == AiMode.online
                            ? Colors.green
                            : PadhAiColors.secondary,
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
                          : PadhAiColors.secondary)
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
                  ? PadhAiColors.secondary
                  : null,
            ),
          ),
          const PadhAccountMenuButton(),
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
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              itemCount: _lines.length + (showTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (showTyping && i == _lines.length) {
                  return const _TypingBlock();
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
                                    color: PadhAiColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: PadhAiColors.secondary.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Text('🍃', style: TextStyle(fontSize: 16)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: RepaintBoundary(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? PadhAiColors.bubbleUser
                                          : PadhAiColors.bubbleAi,
                                      borderRadius: BorderRadius.circular(14),
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
                                          ? Text(
                                              line.content,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(color: PadhAiColors.textPrimary),
                                            )
                                          : (line.streaming
                                              // Streaming: render as plain selectable text to avoid
                                              // re-parsing markdown/LaTeX on every token.
                                              ? SelectableText(
                                                  line.content,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: PadhAiColors.textPrimary,
                                                      ),
                                                )
                                              // Final: markdown + LaTeX (English or in-app Nepali).
                                              : _buildAssistantMessageBody(line, context)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            df.format(line.createdAt),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: PadhAiColors.textSecondary,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: PadhAiColors.secondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Type your question... / आफ्नो प्रश्न लेख्नुहोस्...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _input,
                      builder: (context, value, _) {
                        final empty = value.text.trim().isEmpty;
                        return IconButton(
                          onPressed: (_thinking || empty) ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                          color: PadhAiColors.secondary,
                        );
                      },
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
  });

  final int? dbId;
  final String role;
  final String content;
  final DateTime createdAt;
  final bool streaming;

  static _ChatLine fromDb(Map<String, Object?> m) {
    return _ChatLine(
      dbId: m['id'] as int,
      role: m['role'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

class _TypingBlock extends StatelessWidget {
  const _TypingBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PadhAiColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Text('📖', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BouncingDots(),
                const SizedBox(height: 6),
                Text(
                  'GyaanAi is thinking...',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: PadhAiColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * 0.2) % 1.0;
            final y = (t < 0.5 ? t * 2 : (1 - t) * 2) * 6;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Transform.translate(
                offset: Offset(0, -y),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: PadhAiColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
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

  /// Remove all `$` characters so the markdown parser doesn't choke.
  static String _stripDollars(String s) {
    var out = s.replaceAllMapped(
      RegExp(r'\$\$(.+?)\$\$', dotAll: true),
      (m) => m.group(1) ?? '',
    );
    out = out.replaceAllMapped(
      RegExp(r'\$(.+?)\$'),
      (m) => m.group(1) ?? '',
    );
    // Catch any remaining lone $ signs
    return out.replaceAll('\$', '');
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
