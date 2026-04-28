import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/slide_route.dart';
import '../providers/gyaan_ai_providers.dart';
import '../screens/auth/login_screen.dart';
import '../screens/gyaan_ai_settings_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/gyaan_ai_theme.dart';

/// App bar menu: Settings, Profile / Sign in, Log out.
class GyaanAiAccountMenuButton extends ConsumerWidget {
  const GyaanAiAccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appSettingsProvider);
    final loggedIn =
        settings.accessToken != null && settings.accessToken!.isNotEmpty;

    return PopupMenuButton<String>(
      icon: Icon(
        loggedIn ? Icons.account_circle : Icons.account_circle_outlined,
        color: GyaanAiColors.primary,
      ),
      tooltip: 'Account',
      onSelected: (value) async {
        if (value == 'settings') {
          await Navigator.of(context).push(
            slideFromRight(const GyaanAiSettingsScreen()),
          );
          return;
        }
        if (value == 'profile') {
          await Navigator.of(context).push(
            slideFromRight(const ProfileScreen()),
          );
          return;
        }
        if (value == 'login') {
          await Navigator.of(context).push(
            slideFromRight(const LoginScreen()),
          );
          return;
        }
        if (value == 'logout') {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            await ref.read(apiServiceProvider).logout();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                slideFromRight(const LoginScreen()),
                (_) => false,
              );
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        PopupMenuItem(
          value: loggedIn ? 'profile' : 'login',
          child: ListTile(
            leading: Icon(loggedIn ? Icons.person_outline : Icons.login),
            title: Text(loggedIn ? 'Profile' : 'Sign in'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        if (loggedIn)
          const PopupMenuItem(
            value: 'logout',
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Log out', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
      ],
    );
  }
}
