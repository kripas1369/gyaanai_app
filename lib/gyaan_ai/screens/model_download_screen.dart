import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../services/model_loader_service.dart';
import '../theme/gyaan_ai_theme.dart';
import 'grade_selection_screen.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  ModelDownloadProgress? _progress;
  bool _isDownloading = false;
  bool _isConnecting = false;
  bool _serverConnected = false;
  String? _errorMessage;
  int _modelSizeBytes = 0;
  StreamSubscription<ModelDownloadProgress>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _connectToServer() async {
    setState(() {
      _isConnecting = true;
      _serverConnected = false;
      _errorMessage = null;
    });

    final settings = ref.read(appSettingsProvider);
    final loader = ref.read(modelLoaderProvider);
    // Always sync the URL from settings before connecting
    loader.setDjangoBaseUrl(settings.djangoBaseUrl);

    try {
      final info = await loader.fetchModelInfo();
      if (!mounted) return;
      if (info != null) {
        _modelSizeBytes = info['size_bytes'] as int? ?? loader.expectedModelSize;
        setState(() {
          _serverConnected = true;
          _isConnecting = false;
        });

        final bytesDownloaded = await loader.getBytesDownloaded();
        if (mounted && bytesDownloaded > 0 && bytesDownloaded < _modelSizeBytes) {
          setState(() {
            _progress = ModelDownloadProgress(
              status: DownloadStatus.connecting,
              bytesDownloaded: bytesDownloaded,
              totalBytes: _modelSizeBytes,
            );
          });
        }
      } else {
        setState(() {
          _serverConnected = false;
          _isConnecting = false;
          _errorMessage = 'Could not reach the backend. Try again later.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverConnected = false;
        _isConnecting = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    final loader = ref.read(modelLoaderProvider);
    try {
      _downloadSub = loader.downloadModel().listen(
        (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
          if (progress.status == DownloadStatus.complete) {
            _onDownloadComplete();
          } else if (progress.status == DownloadStatus.error) {
            setState(() {
              _isDownloading = false;
              _errorMessage = progress.error ?? 'Download failed';
            });
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _errorMessage = e.toString();
          });
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onDownloadComplete() => _loadModelAndContinue();

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(slideFromRight(const GradeSelectionScreen()));
  }

  Future<void> _loadModelAndContinue() async {
    setState(() => _progress = ModelDownloadProgress(
      status: DownloadStatus.verifying,
      bytesDownloaded: _progress?.bytesDownloaded ?? 0,
      totalBytes: _progress?.totalBytes ?? 0,
    ));
    try {
      final gemma = ref.read(gemmaOfflineProvider);
      await gemma.loadModel();
      _navigateToMain();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load model: $e';
        _isDownloading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final loader = ref.watch(modelLoaderProvider);
    final sizeBytes = _modelSizeBytes > 0 ? _modelSizeBytes : loader.expectedModelSize;
    final modelSizeText = _formatBytes(sizeBytes);
    final hasPartialDownload =
        _progress != null && _progress!.bytesDownloaded > 0 && !_isDownloading;

    return Scaffold(
      backgroundColor: GyaanAiColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: GyaanAiColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: GyaanAiColors.secondary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isDownloading ? Icons.download_rounded : Icons.smart_toy_rounded,
                    size: 46,
                    color: GyaanAiColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Download AI Model',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: GyaanAiColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'GyaanAI works fully offline after downloading the Gemma 4 model ($modelSizeText). '
                'Tap Download to start.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: GyaanAiColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 24),

              // Download section
              if (_isConnecting) ...[
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Checking model from backend...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: GyaanAiColors.textSecondary,
                      ),
                ),
              ] else ...[
                if (_isDownloading && _progress != null)
                  _DownloadProgress(
                    progress: _progress!,
                    onFormatBytes: _formatBytes,
                  )
                else if (_serverConnected)
                  _DownloadButton(
                    modelSizeText: modelSizeText,
                    hasPartial: hasPartialDownload,
                    partialBytes: _progress?.bytesDownloaded ?? 0,
                    onFormatBytes: _formatBytes,
                    onDownload: _startDownload,
                  ),
              ],

              // Error
              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                _ErrorCard(message: _errorMessage!),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _connectToServer,
                  style: FilledButton.styleFrom(
                    backgroundColor: GyaanAiColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try again'),
                ),
              ],

              const SizedBox(height: 40),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 15,
                    color: GyaanAiColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Works fully offline after download',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: GyaanAiColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.modelSizeText,
    required this.hasPartial,
    required this.partialBytes,
    required this.onFormatBytes,
    required this.onDownload,
  });

  final String modelSizeText;
  final bool hasPartial;
  final int partialBytes;
  final String Function(int) onFormatBytes;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onDownload,
          icon: Icon(hasPartial ? Icons.refresh_rounded : Icons.download_rounded),
          label: Text(
            hasPartial ? 'Resume Download' : 'Download ($modelSizeText)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: GyaanAiColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (hasPartial) ...[
          const SizedBox(height: 8),
          Text(
            '${onFormatBytes(partialBytes)} already downloaded',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: GyaanAiColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress, required this.onFormatBytes});

  final ModelDownloadProgress progress;
  final String Function(int) onFormatBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 14,
            backgroundColor: GyaanAiColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(GyaanAiColors.secondary),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${(progress.progress * 100).toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: GyaanAiColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          progress.statusText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: GyaanAiColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${onFormatBytes(progress.bytesDownloaded)} / ${onFormatBytes(progress.totalBytes)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: GyaanAiColors.textSecondary,
          ),
        ),
        if (progress.speedText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: GyaanAiColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 15, color: GyaanAiColors.secondary),
                const SizedBox(width: 5),
                Text(
                  progress.speedText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GyaanAiColors.secondary,
                  ),
                ),
                if (progress.timeRemainingText.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    '• ${progress.timeRemainingText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: GyaanAiColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
