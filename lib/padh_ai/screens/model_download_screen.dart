import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/padh_ai_providers.dart';
import '../services/model_loader_service.dart';
import '../theme/padh_ai_theme.dart';
import 'grade_selection_screen.dart';

/// Simple screen to download the AI model.
/// Auto-connects to server and shows download button.
class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  ModelDownloadProgress? _progress;
  bool _isDownloading = false;
  bool _isConnecting = true;
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

  /// Auto-connect to server on load.
  Future<void> _connectToServer() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final loader = ref.read(modelLoaderProvider);

    try {
      final info = await loader.fetchModelInfo();
      if (info != null) {
        _modelSizeBytes = info['size_bytes'] as int? ?? loader.expectedModelSize;
        setState(() {
          _serverConnected = true;
          _isConnecting = false;
        });

        // Check for partial download
        final bytesDownloaded = await loader.getBytesDownloaded();
        if (bytesDownloaded > 0 && bytesDownloaded < _modelSizeBytes) {
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
          _errorMessage = 'Cannot connect to server. Make sure Django is running.';
        });
      }
    } catch (e) {
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

  void _onDownloadComplete() {
    _loadModelAndContinue();
  }

  void _navigateToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      slideFromRight(const GradeSelectionScreen()),
    );
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
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final loader = ref.watch(modelLoaderProvider);
    final sizeBytes = _modelSizeBytes > 0 ? _modelSizeBytes : loader.expectedModelSize;
    final modelSizeText = _formatBytes(sizeBytes);
    final hasPartialDownload =
        _progress != null && _progress!.bytesDownloaded > 0 && !_isDownloading;

    return Scaffold(
      backgroundColor: PadhAiColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: PadhAiColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PadhAiColors.secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  _isDownloading ? Icons.download_rounded : Icons.smart_toy_rounded,
                  size: 48,
                  color: PadhAiColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Download AI Model',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: PadhAiColors.primary,
                    ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'To use GyaanAi offline, you need to download the AI model ($modelSizeText).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PadhAiColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),

              // Connecting state
              if (_isConnecting) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Connecting to server...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PadhAiColors.textSecondary,
                      ),
                ),
              ]

              // Download Progress
              else if (_isDownloading && _progress != null) ...[
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress!.progress,
                    minHeight: 16,
                    backgroundColor: PadhAiColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      PadhAiColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Percentage
                Text(
                  '${(_progress!.progress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: PadhAiColors.primary,
                      ),
                ),
                const SizedBox(height: 8),

                // Status
                Text(
                  _progress!.statusText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: PadhAiColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),

                // Size progress
                Text(
                  '${_formatBytes(_progress!.bytesDownloaded)} / ${_formatBytes(_progress!.totalBytes)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PadhAiColors.textSecondary,
                      ),
                ),

                // Speed and time remaining
                if (_progress!.speedText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: PadhAiColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, size: 16, color: PadhAiColors.secondary),
                        const SizedBox(width: 6),
                        Text(
                          _progress!.speedText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PadhAiColors.secondary,
                          ),
                        ),
                        if (_progress!.timeRemainingText.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(
                            '• ${_progress!.timeRemainingText}',
                            style: TextStyle(
                              fontSize: 13,
                              color: PadhAiColors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ]

              // Download button
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _serverConnected ? _startDownload : _connectToServer,
                    icon: Icon(
                      _serverConnected
                          ? (hasPartialDownload ? Icons.refresh_rounded : Icons.download_rounded)
                          : Icons.refresh_rounded,
                    ),
                    label: Text(
                      _serverConnected
                          ? (hasPartialDownload ? 'Resume Download' : 'Download ($modelSizeText)')
                          : 'Retry Connection',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: PadhAiColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                if (hasPartialDownload) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_formatBytes(_progress!.bytesDownloaded)} already downloaded',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PadhAiColors.textSecondary,
                        ),
                  ),
                ],
              ],

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Make sure Django server is running:\npython manage.py runserver 0.0.0.0:8000',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: PadhAiColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Works offline after download',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: PadhAiColors.textSecondary.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
