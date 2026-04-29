import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../services/gemma_offline_service.dart';
import '../theme/gyaan_ai_theme.dart';
import 'grade_selection_screen.dart';
import 'model_download_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  String _status = 'Starting...';
  double _progress = 0.0;
  String? _error;

  late final AnimationController _logoCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _particleCtrl;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  static const _features = [
    ('🇳🇵', 'Nepal Curriculum', 'Class 1–10 + SEE'),
    ('🤖', 'Gemma 4 AI', 'On-device & offline'),
    ('📷', 'Photo Q&A', 'Snap & solve'),
  ];

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic),
    );

    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(milliseconds: 120));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _contentCtrl.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      _setStatus('Checking AI model...', 0.2);
      final gemma = ref.read(gemmaOfflineProvider);

      if (!GemmaOfflineService.platformSupported) {
        _goToDownload();
        return;
      }

      final modelPath = await ModelManager.findModel();
      if (modelPath == null) {
        _goToDownload();
        return;
      }

      _setStatus('Loading Gemma 4...', 0.55);
      final success = await gemma.initialize(skipWarmup: true);

      if (success) {
        _setStatus('Ready!', 1.0);
        await Future.delayed(const Duration(milliseconds: 350));
        _navigateToMain();
      } else {
        _goToDownload();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _setStatus(String s, double p) {
    if (mounted) setState(() { _status = s; _progress = p; });
  }

  void _navigateToMain() {
    if (!mounted) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.isOnboardingDone) {
      Navigator.of(context).pushReplacement(slideFromRight(const OnboardingScreen()));
    } else {
      Navigator.of(context).pushReplacement(slideFromRight(const GradeSelectionScreen()));
    }
  }

  void _goToDownload() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(slideFromRight(const ModelDownloadScreen()));
  }

  void _retry() {
    setState(() { _error = null; _progress = 0; });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Deep gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2E14), Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Animated floating particles
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(_particleCtrl.value),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Logo + brand
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Column(
                        children: [
                          // Logo ring
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF43A047).withValues(alpha: 0.5),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('📚', style: TextStyle(fontSize: 56)),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Brand name
                          Text(
                            'GyaanAI',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ज्ञान — Your AI Tutor',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Feature pills
                FadeTransition(
                  opacity: _contentOpacity,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _features.map((f) => _FeaturePill(
                          emoji: f.$1,
                          title: f.$2,
                          subtitle: f.$3,
                        )).toList(),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Status / error
                FadeTransition(
                  opacity: _contentOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: _error != null
                        ? _ErrorCard(error: _error!, onRetry: _retry)
                        : _StatusBar(status: _status, progress: _progress),
                  ),
                ),

                const SizedBox(height: 32),

                // Bottom badge
                FadeTransition(
                  opacity: _contentOpacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          'Powered by Gemma 4 • Google DeepMind',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.emoji, required this.title, required this.subtitle});
  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status, required this.progress});
  final String status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              status,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Could not initialize',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: GyaanAiColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Floating soft circles in the background for depth.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);
  final double t;

  static final _rng = math.Random(42);
  static final _dots = List.generate(18, (_) => _rng.nextDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _dots.length; i += 3) {
      final phase = (_dots[i] + t * 0.3) % 1.0;
      final x = _dots[i + 1 < _dots.length ? i + 1 : i] * size.width;
      final y = ((_dots[i + 2 < _dots.length ? i + 2 : i] + phase * 0.15) % 1.0) * size.height;
      final r = 4.0 + (_dots[i] * 20);
      paint.color = Colors.white.withValues(alpha: 0.03 + _dots[i] * 0.04);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
