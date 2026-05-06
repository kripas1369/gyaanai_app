import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/subject_catalog.dart';
import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/scaffold_with_banner.dart';
import 'chat_history_screen.dart';
import 'subject_selection_screen.dart';

class GradeSelectionScreen extends ConsumerStatefulWidget {
  const GradeSelectionScreen({super.key});

  @override
  ConsumerState<GradeSelectionScreen> createState() => _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends ConsumerState<GradeSelectionScreen>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'gyaan_last_grade';
  int? _highlightGrade;
  late final AnimationController _waveCtrl;
  String _studentName = '';

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _loadLast();
    _loadStudentName();
  }

  Future<void> _loadStudentName() async {
    final settings = ref.read(appSettingsProvider);
    if (mounted) setState(() => _studentName = settings.studentName);
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
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

  ({Color accent, Color bg, Color fg, String emoji, String band}) _styleForGrade(int grade) {
    if (grade <= 3) {
      return (
        accent: const Color(0xFFFF8F00),
        bg: const Color(0xFFFFF8E1),
        fg: const Color(0xFFE65100),
        emoji: ['✏️', '🖊️', '📒'][grade - 1],
        band: 'Primary',
      );
    }
    if (grade <= 7) {
      return (
        accent: const Color(0xFF1565C0),
        bg: const Color(0xFFE3F2FD),
        fg: const Color(0xFF0D47A1),
        emoji: ['📘', '📗', '📙', '🔬'][grade - 4],
        band: 'Middle',
      );
    }
    return (
      accent: const Color(0xFF2E7D32),
      bg: const Color(0xFFE8F5E9),
      fg: const Color(0xFF1B5E20),
      emoji: ['🌿', '🎯', '🏆'][grade - 8],
      band: grade >= 9 ? 'SEE Prep' : 'Secondary',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithBanner(
      appBar: AppBar(
        title: const Text('GyaanAI'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBanner(waveCtrl: _waveCtrl, studentName: _studentName),
            const SizedBox(height: 20),
            // General AI tile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GeneralAiTile(onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  slideFromRight(ChatHistoryScreen(grade: 0, subject: generalSubject)),
                );
              }),
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: 'Primary', subtitle: 'Classes 1–3', color: const Color(0xFFFF8F00)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var g = 1; g <= 3; g++) ...[
                    if (g > 1) const SizedBox(width: 10),
                    Expanded(child: _GradeTile(
                      grade: g,
                      style: _styleForGrade(g),
                      isHighlighted: _highlightGrade == g,
                      nepaliDigit: _nepaliDigit(g),
                      onTap: () => _onGradeTap(g),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: 'Middle', subtitle: 'Classes 4–7', color: const Color(0xFF1565C0)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final crossAxisCount = w >= 520
                      ? 4
                      : w >= 380
                          ? 3
                          : 2;

                  // More height on smaller widths to avoid RenderFlex overflow.
                  final childAspectRatio = switch (crossAxisCount) { 4 => 0.72, 3 => 0.82, _ => 0.92 };

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      final g = 4 + index;
                      return _GradeTile(
                        grade: g,
                        style: _styleForGrade(g),
                        isHighlighted: _highlightGrade == g,
                        nepaliDigit: _nepaliDigit(g),
                        onTap: () => _onGradeTap(g),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: 'Secondary', subtitle: 'Classes 8–9', color: const Color(0xFF2E7D32)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (var g = 8; g <= 9; g++) ...[
                    if (g > 8) const SizedBox(width: 10),
                    Expanded(child: _GradeTile(
                      grade: g,
                      style: _styleForGrade(g),
                      isHighlighted: _highlightGrade == g,
                      nepaliDigit: _nepaliDigit(g),
                      onTap: () => _onGradeTap(g),
                    )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: 'SEE Preparation', subtitle: 'Class 10 — Board Exam', color: const Color(0xFF6A1B9A)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SeeTile(
                isHighlighted: _highlightGrade == 10,
                onTap: () => _onGradeTap(10),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _onGradeTap(int grade) async {
    HapticFeedback.selectionClick();
    setState(() => _highlightGrade = grade);
    await _saveGrade(grade);
    if (!mounted) return;
    Navigator.of(context).push(slideFromRight(SubjectSelectionScreen(grade: grade)));
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.waveCtrl, required this.studentName});
  final AnimationController waveCtrl;
  final String studentName;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = studentName.isNotEmpty
        ? '${_greeting()}, $studentName! 👋'
        : 'नमस्ते! Welcome 👋';

    return AnimatedBuilder(
      animation: waveCtrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 168,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2E14), Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E20).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width - 32, 168),
              painter: _WavePainter(waveCtrl.value),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'GyaanAI — ज्ञान AI',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Nepal Curriculum • Powered by Gemma 4',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Pill(icon: Icons.offline_bolt_rounded, label: 'Offline AI'),
                            const SizedBox(width: 6),
                            _Pill(icon: Icons.camera_alt_rounded, label: 'Photo Q&A'),
                            const SizedBox(width: 6),
                            _Pill(icon: Icons.translate_rounded, label: 'नेपाली'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Text('🎓', style: TextStyle(fontSize: 56)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.subtitle, required this.color});
  final String label;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: GyaanAiColors.textSecondary)),
        ],
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({
    required this.grade,
    required this.style,
    required this.isHighlighted,
    required this.nepaliDigit,
    required this.onTap,
  });

  final int grade;
  final ({Color accent, Color bg, Color fg, String emoji, String band}) style;
  final bool isHighlighted;
  final String nepaliDigit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: style.bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted ? style.accent : style.fg.withValues(alpha: 0.18),
              width: isHighlighted ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHighlighted
                    ? style.accent.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isHighlighted ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(style.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                nepaliDigit,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: style.fg),
              ),
              Text(
                'Class $grade',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: GyaanAiColors.textSecondary,
                ),
              ),
              if (isHighlighted) ...[
                const SizedBox(height: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeTile extends StatelessWidget {
  const _SeeTile({required this.isHighlighted, required this.onTap});
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted ? Colors.white.withValues(alpha: 0.6) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🏆', style: TextStyle(fontSize: 34))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'कक्षा १०',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'SEE',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secondary Education Exam',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _SeePill(icon: Icons.quiz_rounded, label: 'All Subjects'),
                        const SizedBox(width: 6),
                        _SeePill(icon: Icons.star_rounded, label: 'Exam Ready'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeePill extends StatelessWidget {
  const _SeePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 9, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GeneralAiTile extends StatelessWidget {
  const _GeneralAiTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5C35C9), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🤖', style: TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'General AI',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Ask anything • सामान्य प्रश्न',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  static final _rng = math.Random(99);
  static final _dots = List.generate(24, (_) => _rng.nextDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _dots.length; i += 3) {
      final phase = (_dots[i] + t * 0.25) % 1.0;
      final x = _dots[i + 1 < _dots.length ? i + 1 : i] * size.width;
      final y = ((_dots[i + 2 < _dots.length ? i + 2 : i] + phase * 0.12) % 1.0) * size.height;
      final r = 3.0 + _dots[i] * 16;
      paint.color = Colors.white.withValues(alpha: 0.03 + _dots[i] * 0.035);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}
