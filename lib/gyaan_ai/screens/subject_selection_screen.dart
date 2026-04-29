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

  ({Color color, Color light, IconData icon}) _subjectStyle(String key) {
    return switch (key) {
      'math'     => (color: const Color(0xFF1976D2), light: const Color(0xFFE3F2FD), icon: Icons.functions_rounded),
      'science'  => (color: const Color(0xFF388E3C), light: const Color(0xFFE8F5E9), icon: Icons.science_rounded),
      'english'  => (color: const Color(0xFF7B1FA2), light: const Color(0xFFF3E5F5), icon: Icons.menu_book_rounded),
      'nepali'   => (color: const Color(0xFFC62828), light: const Color(0xFFFFEBEE), icon: Icons.translate_rounded),
      'social'   => (color: const Color(0xFFE65100), light: const Color(0xFFFFF3E0), icon: Icons.public_rounded),
      'computer' => (color: const Color(0xFF00838F), light: const Color(0xFFE0F7FA), icon: Icons.computer_rounded),
      'health'   => (color: const Color(0xFFAD1457), light: const Color(0xFFFCE4EC), icon: Icons.favorite_rounded),
      'opt_math' => (color: const Color(0xFF283593), light: const Color(0xFFE8EAF6), icon: Icons.calculate_rounded),
      _          => (color: GyaanAiColors.secondary, light: const Color(0xFFE8F5E9), icon: Icons.book_rounded),
    };
  }

  ({Color gradStart, Color gradEnd, String emoji, String label}) _bandForGrade(int grade) {
    if (grade <= 3) {
      return (
        gradStart: const Color(0xFFFF6F00),
        gradEnd: const Color(0xFFFF8F00),
        emoji: '✏️',
        label: 'Primary Level',
      );
    }
    if (grade <= 7) {
      return (
        gradStart: const Color(0xFF1565C0),
        gradEnd: const Color(0xFF1976D2),
        emoji: '📘',
        label: 'Middle Level',
      );
    }
    if (grade <= 9) {
      return (
        gradStart: const Color(0xFF1B5E20),
        gradEnd: const Color(0xFF388E3C),
        emoji: '🌿',
        label: 'Secondary Level',
      );
    }
    return (
      gradStart: const Color(0xFF4A148C),
      gradEnd: const Color(0xFF7B1FA2),
      emoji: '🏆',
      label: 'SEE Preparation',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = subjectsForGrade(grade);
    final band = _bandForGrade(grade);

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Select Subject',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GyaanAiColors.textSecondary),
            ),
          ],
        ),
        actions: const [GyaanAiAccountMenuButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grade header banner
          _GradeHeaderBanner(grade: grade, band: band, subjectCount: subjects.length, nepaliDigit: _nepaliDigit(grade)),
          // Subjects grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemCount: subjects.length,
              itemBuilder: (context, i) {
                final s = subjects[i];
                final style = _subjectStyle(s.key);
                return _SubjectCard(
                  subject: s,
                  style: style,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      slideFromRight(ChatHistoryScreen(grade: grade, subject: s)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeHeaderBanner extends StatelessWidget {
  const _GradeHeaderBanner({
    required this.grade,
    required this.band,
    required this.subjectCount,
    required this.nepaliDigit,
  });

  final int grade;
  final ({Color gradStart, Color gradEnd, String emoji, String label}) band;
  final int subjectCount;
  final String nepaliDigit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [band.gradStart, band.gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: band.gradStart.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(band.emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'कक्षा $nepaliDigit — Class $grade',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  band.label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BandPill(icon: Icons.book_rounded, label: '$subjectCount Subjects'),
                    const SizedBox(width: 6),
                    _BandPill(icon: Icons.camera_alt_rounded, label: 'Photo Q&A'),
                    const SizedBox(width: 6),
                    _BandPill(icon: Icons.offline_bolt_rounded, label: 'Offline'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BandPill extends StatelessWidget {
  const _BandPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.style, required this.onTap});

  final SubjectItem subject;
  final ({Color color, Color light, IconData icon}) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: style.light,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: style.color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: style.color.withValues(alpha: 0.08),
                blurRadius: 14,
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [style.color, style.color.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: style.color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(subject.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 15, color: style.color),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                subject.nepali,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: GyaanAiColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subject.english,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: style.color,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 10, color: style.color),
                    const SizedBox(width: 4),
                    Text(
                      'Nepal Curriculum',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
