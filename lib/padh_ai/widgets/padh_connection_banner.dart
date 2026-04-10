import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/padh_ai_providers.dart';
import '../theme/padh_ai_theme.dart';

/// Small persistent status strip for post-splash screens.
class PadhConnectionBanner extends ConsumerWidget {
  const PadhConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(padhConnectivityProvider);
    return async.when(
      data: (mode) {
        final (dotColor, label) = switch (mode) {
          PadhConnectivityLabel.online => (
              Colors.green,
              'Online',
            ),
          PadhConnectivityLabel.offlineLocal => (
              Colors.orange,
              'Offline — AI Running Locally',
            ),
        };
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: PadhAiColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 4),
      error: (Object? error, StackTrace stackTrace) => const SizedBox.shrink(),
    );
  }
}
