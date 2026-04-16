import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../providers/padh_ai_providers.dart';
import '../theme/padh_ai_theme.dart';
import '../widgets/padh_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';
import 'padh_chat_screen.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({
    super.key,
    required this.grade,
    required this.subject,
  });

  final int grade;
  final SubjectItem subject;

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  late Future<List<_SessionRow>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<List<_SessionRow>> _load() async {
    final repo = ref.read(padhChatRepoProvider);
    final rows = await repo.sessionsForGradeSubject(
      widget.grade,
      widget.subject.key,
    );
    final out = <_SessionRow>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final title = r['title'] as String;
      final lastAt = DateTime.parse(r['last_message_at'] as String);
      final preview = await repo.lastPreview(id);
      out.add(
        _SessionRow(
          id: id,
          title: title,
          lastAt: lastAt,
          preview: preview ?? '',
        ),
      );
    }
    return out;
  }

  Future<void> _openNewChat() async {
    final repo = ref.read(padhChatRepoProvider);
    final id = await repo.createEmptySession(
      grade: widget.grade,
      subjectKey: widget.subject.key,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      slideFromRight(
        PadhChatScreen(
          grade: widget.grade,
          subject: widget.subject,
          sessionId: id,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, y • h:mm a');
    return ScaffoldWithBanner(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${widget.subject.english} — Class ${widget.grade}'),
        actions: const [PadhAccountMenuButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewChat,
        icon: const Icon(Icons.add),
        label: const Text('New Chat +'),
        backgroundColor: PadhAiColors.secondary,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FutureBuilder<List<_SessionRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '📚',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No chats yet. Tap + to start learning!\n'
                      'अझै कुनै च्याट छैन। + थिचेर सुरु गर्नुहोस्।',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: PadhAiColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = rows[i];
              return Material(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    await Navigator.of(context).push(
                      slideFromRight(
                        PadhChatScreen(
                          grade: widget.grade,
                          subject: widget.subject,
                          sessionId: r.id,
                        ),
                      ),
                    );
                    if (mounted) setState(_reload);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          r.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          df.format(r.lastAt),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: PadhAiColors.textSecondary,
                              ),
                        ),
                        if (r.preview.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            r.preview.length > 120
                                ? '${r.preview.substring(0, 120)}…'
                                : r.preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: PadhAiColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionRow {
  _SessionRow({
    required this.id,
    required this.title,
    required this.lastAt,
    required this.preview,
  });

  final int id;
  final String title;
  final DateTime lastAt;
  final String preview;
}
