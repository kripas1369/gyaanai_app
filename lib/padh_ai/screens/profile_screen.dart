import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/api_service.dart';
import '../navigation/slide_route.dart';
import '../providers/padh_ai_providers.dart';
import '../theme/padh_ai_theme.dart';
import 'auth/login_screen.dart';
import 'padh_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final token = ref.read(appSettingsProvider).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _needsLogin = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final data = await ref.read(apiServiceProvider).getProfile();
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        setState(() {
          _needsLogin = true;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load profile (${e.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to sync with the server.'),
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
    if (ok != true || !mounted) return;
    await ref.read(apiServiceProvider).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      slideFromRight(const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PadhAiColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: PadhAiColors.background,
        foregroundColor: PadhAiColors.primary,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              slideFromRight(const PadhSettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needsLogin
              ? _buildNeedsLogin(context)
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildProfile(context),
    );
  }

  Widget _buildNeedsLogin(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 64,
              color: PadhAiColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'You are not signed in',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to save your profile and use server features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PadhAiColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                slideFromRight(const LoginScreen()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: PadhAiColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    final p = _profile!;
    final username = p['username'] as String? ?? '';
    final email = p['email'] as String? ?? '';
    final userType = p['user_type'] as String?;
    final profile = p['profile'] as Map<String, dynamic>?;

    String? fullName;
    int? grade;
    if (profile != null) {
      fullName = profile['full_name'] as String?;
      final g = profile['grade'];
      if (g is int) grade = g;
      if (g is num) grade = g.toInt();
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: PadhAiColors.primary.withValues(alpha: 0.15),
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: PadhAiColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          fullName ?? username,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (fullName != null && fullName != username) ...[
          const SizedBox(height: 4),
          Text(
            username,
            textAlign: TextAlign.center,
            style: TextStyle(color: PadhAiColors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        _tile(Icons.badge_outlined, 'Account type', userType ?? '—'),
        if (email.isNotEmpty) _tile(Icons.email_outlined, 'Email', email),
        if (grade != null) _tile(Icons.school_outlined, 'Class', '$grade'),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            slideFromRight(const PadhSettingsScreen()),
          ),
          icon: const Icon(Icons.settings),
          label: const Text('App settings'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: PadhAiColors.secondary),
        title: Text(label, style: TextStyle(color: PadhAiColors.textSecondary, fontSize: 13)),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: PadhAiColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
