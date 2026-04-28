import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/gyaan_ai_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';
import 'chat_history_screen.dart';
import 'local_model_test_screen.dart';
import 'subject_selection_screen.dart';

class GradeSelectionScreen extends ConsumerStatefulWidget {
  const GradeSelectionScreen({super.key});

  @override
  ConsumerState<GradeSelectionScreen> createState() =>
      _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends ConsumerState<GradeSelectionScreen> {
  static const _prefsKey = 'gyaan_last_grade';
  int? _highlightGrade;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final g = prefs.getInt(_prefsKey);
    if (mounted) setState(() => _highlightGrade = g);
  }

  Future<void> _saveGrade(int grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, grade);
  }

  String _nepaliDigit(int n) {
    const d = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    if (n == 10) return '१०';
    return d[n];
  }

  (Color bg, Color fg, String emoji) _styleForGrade(int grade) {
    if (grade <= 3) {
      return (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        '✏️',
      );
    }
    if (grade <= 6) {
      return (
        const Color(0xFFE3F2FD),
        const Color(0xFF1565C0),
        '📘',
      );
    }
    return (
      const Color(0xFFE8F5E9),
      const Color(0xFF2E7D32),
      '🌿',
    );
  }

  Widget _generalAiTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            slideFromRight(
              ChatHistoryScreen(grade: 0, subject: generalSubject),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'General AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Ask anything • सामान्य प्रश्न',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradeTile(int grade, {bool wide = false}) {
    final (bg, fg, emoji) = _styleForGrade(grade);
    final highlight = _highlightGrade == grade;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          HapticFeedback.selectionClick();
          await _saveGrade(grade);
          if (!mounted) return;
          Navigator.of(context).push(
            slideFromRight(SubjectSelectionScreen(grade: grade)),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: wide ? 20 : 14,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight ? GyaanAiColors.accent : fg.withValues(alpha: 0.2),
              width: highlight ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: wide
              ? Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'कक्षा ${_nepaliDigit(grade)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Class $grade',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: GyaanAiColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: GyaanAiColors.accent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'SEE Preparation',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF5D4037),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                      _nepaliDigit(grade),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Class $grade',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: GyaanAiColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBanner(
      appBar: AppBar(
        title: const Text('GyaanAi'),
        actions: [
          const GyaanAiAccountMenuButton(),
          IconButton(
            tooltip: 'Bundled model test',
            icon: const Icon(Icons.memory_rounded),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const LocalModelTestScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'आफ्नो कक्षा छान्नुहोस्',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: GyaanAiColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose Your Class',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: GyaanAiColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 20),
            // General AI - Ask anything
            _generalAiTile(),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                for (var g = 1; g <= 9; g++) _gradeTile(g),
              ],
            ),
            const SizedBox(height: 12),
            _gradeTile(10, wide: true),
          ],
        ),
      ),
    );
  }
}
