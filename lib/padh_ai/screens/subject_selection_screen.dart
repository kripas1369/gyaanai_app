import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../theme/padh_ai_theme.dart';
import '../widgets/padh_account_menu_button.dart';
import '../widgets/scaffold_with_banner.dart';
import 'chat_history_screen.dart';

class SubjectSelectionScreen extends ConsumerWidget {
  const SubjectSelectionScreen({super.key, required this.grade});

  final int grade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = subjectsForGrade(grade);
    return ScaffoldWithBanner(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Class $grade — Select Subject'),
        actions: const [PadhAccountMenuButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: subjects.length,
          itemBuilder: (context, i) {
            final s = subjects[i];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    slideFromRight(
                      ChatHistoryScreen(grade: grade, subject: s),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: PadhAiColors.secondary.withValues(alpha: 0.2),
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
                      Text(
                        s.nepali,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: PadhAiColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.english,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: PadhAiColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        s.emoji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
