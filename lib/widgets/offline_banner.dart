import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (!offline) return const SizedBox.shrink();
    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Offline mode — using local content and Ollama.'),
      ),
    );
  }
}
