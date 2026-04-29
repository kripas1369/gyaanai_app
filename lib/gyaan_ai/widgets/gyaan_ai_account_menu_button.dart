import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../screens/gyaan_ai_settings_screen.dart';
import '../theme/gyaan_ai_theme.dart';

/// App bar avatar button — shows student initials, opens settings menu.
/// No login, no account, no server required.
class GyaanAiAccountMenuButton extends ConsumerWidget {
  const GyaanAiAccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final name = settings.studentName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return PopupMenuButton<String>(
      tooltip: 'Menu',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: _Avatar(initial: initial, name: name),
      ),
      onSelected: (value) async {
        if (value == 'settings') {
          await Navigator.of(context).push(
            slideFromRight(const GyaanAiSettingsScreen()),
          );
        }
      },
      itemBuilder: (context) => [
        // Header with student name
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _MenuHeader(initial: initial, name: name),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined, color: GyaanAiColors.primary),
            title: Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right_rounded, size: 18),
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.name});
  final String initial;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.initial, required this.name});
  final String initial;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Student',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B5E20),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.offline_bolt_rounded, size: 11, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 3),
                    Text(
                      'Offline AI • No account needed',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
