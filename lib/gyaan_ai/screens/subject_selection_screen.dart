import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/gyaan_ai_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';
import 'chat_history_screen.dart';

class SubjectSelectionScreen extends ConsumerWidget {
  const SubjectSelectionScreen({super.key, required this.grade});

  final int grade;

  String _nepaliDigit(int n) {
    const d = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    if (n == 10) return '१०';
    return d[n];
  }

  Color _colorForSubject(String key) {
    return switch (key) {
      'math' => const Color(0xFF2196F3),
      'science' => const Color(0xFF4CAF50),
      'english' => const Color(0xFF9C27B0),
      'nepali' => const Color(0xFFE91E63),
      'social' => const Color(0xFFFF9800),
      'computer' => const Color(0xFF00BCD4),
      'health' => const Color(0xFFFF5722),
      'opt_math' => const Color(0xFF3F51B5),
      _ => GyaanAiColors.secondary,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = subjectsForGrade(grade);
    return ScaffoldWithBanner(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'कक्षा ${_nepaliDigit(grade)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              'Select Subject',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: GyaanAiColors.textSecondary,
                  ),
            ),
          ],
        ),
        actions: const [GyaanAiAccountMenuButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GyaanAiColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${subjects.length} विषयहरू',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: GyaanAiColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Tap to start learning',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: GyaanAiColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, i) {
                final s = subjects[i];
                final subjectColor = _colorForSubject(s.key);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        slideFromRight(
                          ChatHistoryScreen(grade: grade, subject: s),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            subjectColor.withValues(alpha: 0.08),
                            Theme.of(context).colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: subjectColor.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: subjectColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    s.emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: subjectColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            s.nepali,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: GyaanAiColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.english,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: subjectColor,
                                  fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}
