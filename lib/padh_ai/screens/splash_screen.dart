import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/padh_ai_providers.dart';
import '../services/gemma_offline_service.dart';
import '../theme/padh_ai_theme.dart';
import 'grade_selection_screen.dart';
import 'model_download_screen.dart';

/// Simplified splash screen for offline-first mode.
/// Flow:
/// 1. Check if AI model exists locally → if yes, load and go to main app
/// 2. If no model → go directly to download screen
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _loadingStatus = 'Starting...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Minimum splash time for branding
    final minSplashFuture = Future.delayed(const Duration(milliseconds: 1500));

    try {
      setState(() => _loadingStatus = 'Checking AI model...');

      final gemma = ref.read(gemmaOfflineProvider);

      // Check if platform supports offline AI
      if (!GemmaOfflineService.platformSupported) {
        setState(() => _loadingStatus = 'Platform not supported for offline AI');
        await minSplashFuture;
        _goToDownload();
        return;
      }

      // Check if model file exists locally
      final modelPath = await ModelManager.findModel();

      if (modelPath == null) {
        // No model found → go to download screen
        setState(() => _loadingStatus = 'AI model not found');
        await minSplashFuture;
        _goToDownload();
        return;
      }

      // Model found → load LiteRT only (skip full warm-up generation — that can take
      // many minutes on Android and looked like a frozen splash; first chat validates).
      setState(() => _loadingStatus = 'Loading AI model...');
      final success = await gemma.initialize(skipWarmup: true);

      await minSplashFuture;

      if (success) {
        setState(() => _loadingStatus = 'AI Ready!');
        await Future.delayed(const Duration(milliseconds: 300));
        // Start background warm-up after navigation (doesn't block UI)
        _startBackgroundWarmup(gemma);
        _navigateToMain();
      } else {
        // Model loading failed → go to download screen
        setState(() => _loadingStatus = 'Failed to load model');
        _goToDownload();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Background warm-up: pre-create a chat session so first inference is faster.
  /// This runs after navigation so it doesn't block the splash screen.
  void _startBackgroundWarmup(GemmaOfflineService gemma) {
    // Don't await - let it run in background
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        // Pre-warm by creating a dummy session - this initializes native resources
        // but doesn't block the user from navigating
        debugPrint('GemmaService: Starting background warm-up...');
        // Use a quick inference with minimal output to warm up the model
        await for (final _ in gemma.runInferenceAccumulating(
          grade: 10,
          subjectEnglish: 'General',
          userMessage: 'Hi',
          maxOutputTokens: 5, // Just a few tokens to warm up
        )) {
          // Consume tokens but don't display
        }
        debugPrint('GemmaService: Background warm-up complete');
      } catch (e) {
        // Ignore warm-up errors - first real chat will retry
        debugPrint('GemmaService: Background warm-up failed (will retry on first chat): $e');
      }
    });
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideFromRight(const GradeSelectionScreen()),
    );
  }

  void _goToDownload() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideFromRight(const ModelDownloadScreen()),
    );
  }

  void _retry() {
    setState(() => _error = null);
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PadhAiColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: PadhAiColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: PadhAiColors.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: PadhAiColors.primary,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'GyaanAi',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: PadhAiColors.primary,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Your Offline AI Tutor',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: PadhAiColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 32),

                // Error state
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Loading state
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        PadhAiColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadingStatus,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PadhAiColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
