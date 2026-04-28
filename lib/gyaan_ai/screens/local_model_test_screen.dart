import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gyaan_ai_providers.dart';
import '../services/gemma_offline_service.dart';
import '../theme/gyaan_ai_theme.dart';
import '../widgets/scaffold_with_banner.dart';

class LocalModelTestScreen extends ConsumerStatefulWidget {
  const LocalModelTestScreen({super.key});

  @override
  ConsumerState<LocalModelTestScreen> createState() =>
      _LocalModelTestScreenState();
}

class _LocalModelTestScreenState extends ConsumerState<LocalModelTestScreen> {
  var _loading = false;
  String? _status;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      await ref.read(gemmaOfflineProvider).loadModel();
      setState(
        () => _status =
            'Gemma 4 (LiteRT-LM) installed from asset; ready for chat.',
      );
    } catch (e) {
      setState(() => _status = 'Failed to initialize: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(gemmaOfflineProvider).isLoaded;
    return ScaffoldWithBanner(
      appBar: AppBar(
        title: const Text('Offline tutor test'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Copies the bundled Gemma 4 `.litertlm` into app storage (flutter_gemma / LiteRT-LM), same as chat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: GyaanAiColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            Material(
              color: GyaanAiColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Large models (~2GB+) need free disk space and RAM; first load can be slow.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: GyaanAiColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Model file: ${ModelManager.modelFileName}'),
            const SizedBox(height: 8),
            Text('Loaded: ${loaded ? 'Yes' : 'No'}'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _load,
              child: Text(_loading ? 'Loading…' : 'Load model'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }
}
