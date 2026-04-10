import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/padh_ai_providers.dart';
import '../services/gemma_offline_service.dart';
import '../theme/padh_ai_theme.dart';

/// Shows the current offline/online status and AI model status.
/// Compact indicator for use in AppBar or anywhere in the UI.
class OfflineModeIndicator extends ConsumerWidget {
  const OfflineModeIndicator({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  final bool showLabel;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(padhConnectivityProvider);
    final gemma = ref.watch(gemmaOfflineProvider);

    final isOnline = connectivity.maybeWhen(
      data: (m) => m == PadhConnectivityLabel.online,
      orElse: () => false,
    );

    final aiReady = gemma.isLoaded;

    // Determine status
    final (color, icon, label) = _getStatus(isOnline, aiReady);

    if (compact) {
      return _CompactIndicator(color: color, icon: icon);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: color),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: PadhAiColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
        if (aiReady) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.smart_toy_rounded,
            size: 14,
            color: PadhAiColors.secondary.withValues(alpha: 0.7),
          ),
        ],
      ],
    );
  }

  (Color, IconData, String) _getStatus(bool isOnline, bool aiReady) {
    if (aiReady) {
      if (isOnline) {
        return (Colors.green, Icons.cloud_done_rounded, 'Online + AI Ready');
      } else {
        return (PadhAiColors.secondary, Icons.offline_bolt_rounded, 'Offline AI Active');
      }
    } else {
      if (isOnline) {
        return (Colors.blue, Icons.cloud_rounded, 'Online');
      } else {
        return (Colors.orange, Icons.cloud_off_rounded, 'Offline');
      }
    }
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _CompactIndicator extends StatelessWidget {
  const _CompactIndicator({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: color),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: color),
        ],
      ),
    );
  }
}

/// Full-width banner showing AI status with more details.
/// Use at the top of screens when AI model status is important.
class AiStatusBanner extends ConsumerWidget {
  const AiStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gemma = ref.watch(gemmaOfflineProvider);
    final status = gemma.status;

    if (status == GemmaModelStatus.ready) {
      return const SizedBox.shrink();
    }

    final (color, icon, text) = switch (status) {
      GemmaModelStatus.notFound => (
          Colors.orange,
          Icons.download_rounded,
          'AI model not found — add file to Downloads or app storage',
        ),
      GemmaModelStatus.loading => (
          Colors.blue,
          Icons.hourglass_empty_rounded,
          'Loading AI model...',
        ),
      GemmaModelStatus.error => (
          Colors.red,
          Icons.error_outline_rounded,
          'AI model error: ${gemma.lastError ?? "Unknown"}',
        ),
      GemmaModelStatus.ready => (
          Colors.green,
          Icons.check_circle_rounded,
          'AI ready',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (status == GemmaModelStatus.loading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
        ],
      ),
    );
  }
}
