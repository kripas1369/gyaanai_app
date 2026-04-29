import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/gyaan_ai_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';
import 'gyaan_ai_chat_screen.dart';

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
  List<_SessionRow>? _sessions;
  bool _loading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchVisible = false;

  Color get _subjectColor => _colorForSubjectKey(widget.subject.key);

  Color _colorForSubjectKey(String key) {
    return switch (key) {
      'math'     => const Color(0xFF1976D2),
      'science'  => const Color(0xFF388E3C),
      'english'  => const Color(0xFF7B1FA2),
      'nepali'   => const Color(0xFFC62828),
      'social'   => const Color(0xFFE65100),
      'computer' => const Color(0xFF00838F),
      'health'   => const Color(0xFFAD1457),
      'opt_math' => const Color(0xFF283593),
      'general'  => const Color(0xFF5C35C9),
      _          => GyaanAiColors.secondary,
    };
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final repo = ref.read(gyaanAiChatRepoProvider);
    final rows = await repo.sessionsForGradeSubject(widget.grade, widget.subject.key);
    final out = <_SessionRow>[];
    for (final r in rows) {
      final id = r['id'] as int;
      final title = r['title'] as String;
      final lastAt = DateTime.parse(r['last_message_at'] as String);
      final preview = await repo.lastPreview(id);
      final count = await repo.messageCountForSession(id);
      out.add(_SessionRow(id: id, title: title, lastAt: lastAt, preview: preview ?? '', messageCount: count));
    }
    if (mounted) {
      setState(() {
        _sessions = out;
        _loading = false;
      });
    }
  }

  List<_SessionRow> get _filteredSessions {
    if (_sessions == null) return [];
    if (_searchQuery.isEmpty) return _sessions!;
    final q = _searchQuery.toLowerCase();
    return _sessions!.where((s) =>
      s.title.toLowerCase().contains(q) || s.preview.toLowerCase().contains(q),
    ).toList();
  }

  Future<void> _openNewChat() async {
    HapticFeedback.lightImpact();
    final repo = ref.read(gyaanAiChatRepoProvider);
    final id = await repo.createEmptySession(grade: widget.grade, subjectKey: widget.subject.key);
    if (!mounted) return;
    await Navigator.of(context).push(
      slideFromRight(GyaanAiChatScreen(grade: widget.grade, subject: widget.subject, sessionId: id)),
    );
    if (mounted) _reload();
  }

  Future<void> _deleteSession(_SessionRow session) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Chat?'),
        content: Text('Delete "${session.title}"?\n\nThis will remove all ${session.messageCount} messages permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.deleteSession(session.id);
    ref.read(gemmaOfflineProvider).clearSession(session.id);
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${session.title}"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      _reload();
    }
  }

  Future<void> _clearAllChats() async {
    if (_sessions == null || _sessions!.isEmpty) return;
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Chats?'),
        content: Text(
          'Delete all ${_sessions!.length} chat sessions for ${widget.subject.english}?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final repo = ref.read(gyaanAiChatRepoProvider);
    await repo.deleteAllSessionsForGradeSubject(widget.grade, widget.subject.key);
    for (final s in _sessions!) {
      ref.read(gemmaOfflineProvider).clearSession(s.id);
    }
    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All chats cleared'), behavior: SnackBarBehavior.floating),
      );
      _reload();
    }
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchQuery = '';
        _searchController.clear();
      } else {
        Future.delayed(const Duration(milliseconds: 100), () => _searchFocus.requestFocus());
      }
    });
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;
    final hasChats = _sessions != null && _sessions!.isNotEmpty;
    final color = _subjectColor;

    return ScaffoldWithBanner(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: _searchVisible
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: const InputDecoration(hintText: 'Search chats...', border: InputBorder.none),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(widget.grade == 0 ? 'General AI' : '${widget.subject.english} — Class ${widget.grade}'),
        actions: [
          if (hasChats)
            IconButton(
              icon: Icon(_searchVisible ? Icons.close : Icons.search_rounded),
              onPressed: _toggleSearch,
            ),
          if (hasChats && !_searchVisible)
            PopupMenuButton<String>(
              onSelected: (v) { if (v == 'clear_all') _clearAllChats(); },
              itemBuilder: (c) => [
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_rounded, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear All Chats', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          const GyaanAiAccountMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewChat,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subject header
          _SubjectHeader(
            subject: widget.subject,
            grade: widget.grade,
            color: color,
            chatCount: _sessions?.length ?? 0,
            loading: _loading,
          ),
          Expanded(
            child: _loading
                ? _buildLoading(color)
                : _sessions!.isEmpty
                    ? _buildEmptyState(color)
                    : filtered.isEmpty
                        ? _buildNoSearchResults()
                        : _buildChatList(filtered, color),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: 16),
          Text(
            'Loading chats...',
            style: TextStyle(color: GyaanAiColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
              ),
              child: Center(child: Text(widget.subject.emoji, style: const TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'No Chats Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: GyaanAiColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start learning ${widget.subject.english}\nby asking your first question!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: GyaanAiColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'सिक्न सुरु गर्न प्रश्न सोध्नुहोस्!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: GyaanAiColors.textSecondary),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openNewChat,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start New Chat', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: GyaanAiColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No results for "$_searchQuery"',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: GyaanAiColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<_SessionRow> sessions, Color color) {
    return RefreshIndicator(
      color: color,
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: sessions.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${sessions.length} ${sessions.length == 1 ? 'chat' : 'chats'}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Swipe left to delete',
                    style: TextStyle(color: GyaanAiColors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            );
          }
          final r = sessions[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: Key('session_${r.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                await _deleteSession(r);
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
              ),
              child: _SessionTile(
                row: r,
                color: color,
                relativeTime: _relativeTime(r.lastAt),
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await Navigator.of(context).push(
                    slideFromRight(GyaanAiChatScreen(
                      grade: widget.grade,
                      subject: widget.subject,
                      sessionId: r.id,
                    )),
                  );
                  if (mounted) _reload();
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _showSessionOptions(r);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSessionOptions(_SessionRow r) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  r.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _subjectColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.open_in_new_rounded, color: _subjectColor),
                ),
                title: const Text('Open Chat'),
                onTap: () async {
                  Navigator.pop(c);
                  HapticFeedback.selectionClick();
                  await Navigator.of(context).push(
                    slideFromRight(GyaanAiChatScreen(
                      grade: widget.grade,
                      subject: widget.subject,
                      sessionId: r.id,
                    )),
                  );
                  if (mounted) _reload();
                },
              ),
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
                title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
                subtitle: Text('${r.messageCount} messages'),
                onTap: () {
                  Navigator.pop(c);
                  _deleteSession(r);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({
    required this.subject,
    required this.grade,
    required this.color,
    required this.chatCount,
    required this.loading,
  });

  final SubjectItem subject;
  final int grade;
  final Color color;
  final int chatCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Center(child: Text(subject.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade == 0 ? 'General AI' : '${subject.english} — Class $grade',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GyaanAiColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subject.nepali,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (!loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$chatCount',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.row,
    required this.color,
    required this.relativeTime,
    required this.onTap,
    required this.onLongPress,
  });

  final _SessionRow row;
  final Color color;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: GyaanAiColors.textSecondary.withValues(alpha: 0.7)),
                            const SizedBox(width: 3),
                            Text(
                              relativeTime,
                              style: TextStyle(fontSize: 11, color: GyaanAiColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (row.preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        row.preview.length > 90 ? '${row.preview.substring(0, 90)}…' : row.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: GyaanAiColors.textSecondary, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 10, color: color),
                              const SizedBox(width: 3),
                              Text(
                                '${row.messageCount} messages',
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: GyaanAiColors.textSecondary.withValues(alpha: 0.5)),
            ),
          ],
        ),
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
    required this.messageCount,
  });

  final int id;
  final String title;
  final DateTime lastAt;
  final String preview;
  final int messageCount;
}
