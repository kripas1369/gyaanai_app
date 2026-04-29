import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_settings_service.dart';
import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../theme/gyaan_ai_theme.dart';
import 'grade_selection_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  int? _selectedGrade;
  bool _saving = false;

  late final AnimationController _logoCtrl;
  late final AnimationController _formCtrl;
  late final AnimationController _particleCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _formOpacity;
  late final Animation<Offset> _formSlide;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _formCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5)),
    );
    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic),
    );

    _logoCtrl.forward().then((_) => _formCtrl.forward());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _logoCtrl.dispose();
    _formCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  Future<void> _startLearning() async {
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your class first'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final settings = ref.read(appSettingsProvider);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) await settings.setStudentName(name);
    await settings.setStudentGrade(_selectedGrade!);
    await settings.setLocalGrade(_selectedGrade!);
    await settings.completeOnboarding();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(slideFromRight(const GradeSelectionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Gradient background (top 40%)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A2E14), Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Floating particles (in gradient area)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.42,
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particleCtrl.value),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top: logo area (on gradient)
                SizedBox(
                  height: size.height * 0.38,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, __) => Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF43A047).withValues(alpha: 0.5),
                                      blurRadius: 32,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('📚', style: TextStyle(fontSize: 42)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'GyaanAI',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ज्ञान — Your Offline AI Tutor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom: form card (on white)
                Expanded(
                  child: FadeTransition(
                    opacity: _formOpacity,
                    child: SlideTransition(
                      position: _formSlide,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 30,
                              offset: Offset(0, -6),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Drag handle
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              const Text(
                                'Welcome! Let\'s get started 👋',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No account needed — everything works offline.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Name field
                              _SectionLabel(label: 'Your Name', subtitle: 'Optional'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Hari Prasad',
                                  hintStyle: TextStyle(color: Colors.grey.shade400),
                                  prefixIcon: const Icon(Icons.person_outline_rounded),
                                  filled: true,
                                  fillColor: const Color(0xFFF5F5F5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2E7D32),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Grade selection
                              _SectionLabel(label: 'Your Class', subtitle: 'Required'),
                              const SizedBox(height: 10),
                              _GradeGrid(
                                selectedGrade: _selectedGrade,
                                onSelect: (g) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedGrade = g);
                                },
                              ),
                              const SizedBox(height: 32),

                              // Start button
                              SizedBox(
                                height: 56,
                                child: FilledButton(
                                  onPressed: _saving ? null : _startLearning,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    disabledBackgroundColor: Colors.grey.shade300,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Start Learning',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '→',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Privacy note
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey.shade400),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Stored only on your device — no account, no data shared.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.subtitle});
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: subtitle == 'Required'
                ? const Color(0xFFFFEBEE)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: subtitle == 'Required'
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }
}

class _GradeGrid extends StatelessWidget {
  const _GradeGrid({required this.selectedGrade, required this.onSelect});
  final int? selectedGrade;
  final void Function(int) onSelect;

  static const _grades = [
    (1, '१', '✏️'),
    (2, '२', '🖊️'),
    (3, '३', '📒'),
    (4, '४', '📘'),
    (5, '५', '📗'),
    (6, '६', '📙'),
    (7, '७', '🔬'),
    (8, '८', '🌿'),
    (9, '९', '🎯'),
    (10, '१०', '🏆'),
  ];

  Color _colorForGrade(int g) {
    if (g <= 3) return const Color(0xFFFF8F00);
    if (g <= 7) return const Color(0xFF1565C0);
    if (g <= 9) return const Color(0xFF2E7D32);
    return const Color(0xFF6A1B9A);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: _grades.map((item) {
        final (grade, nepali, emoji) = item;
        final selected = selectedGrade == grade;
        final color = _colorForGrade(grade);

        return GestureDetector(
          onTap: () => onSelect(grade),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : Colors.grey.shade200,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 3),
                Text(
                  nepali,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: selected ? color : const Color(0xFF424242),
                  ),
                ),
                Text(
                  'Class $grade',
                  style: TextStyle(
                    fontSize: 8,
                    color: selected ? color : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);
  final double t;

  static final _rng = math.Random(77);
  static final _dots = List.generate(15, (_) => _rng.nextDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _dots.length; i += 3) {
      final phase = (_dots[i] + t * 0.2) % 1.0;
      final x = _dots[i + 1 < _dots.length ? i + 1 : i] * size.width;
      final y = ((_dots[i + 2 < _dots.length ? i + 2 : i] + phase * 0.1) % 1.0) * size.height;
      final r = 3.0 + (_dots[i] * 18);
      paint.color = Colors.white.withValues(alpha: 0.025 + _dots[i] * 0.04);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
