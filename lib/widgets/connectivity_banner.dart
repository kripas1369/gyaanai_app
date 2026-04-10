import 'package:flutter/material.dart';

import '../data/services/connectivity_mode_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.mode});

  final AppConnectivityMode mode;

  @override
  Widget build(BuildContext context) {
    final (text, icon, color) = switch (mode) {
      AppConnectivityMode.online => ('📡 Online', Icons.cloud_done, Colors.green),
      AppConnectivityMode.localNetwork =>
        ('🏠 Local Network', Icons.router, Colors.amber),
      AppConnectivityMode.offline => ('📴 Offline Mode', Icons.cloud_off, Colors.red),
    };

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

