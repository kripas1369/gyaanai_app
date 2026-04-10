import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_service.dart';
import '../../navigation/slide_route.dart';
import '../../providers/padh_ai_providers.dart';
import '../../theme/padh_ai_theme.dart';
import '../grade_selection_screen.dart';
import '../padh_settings_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final settings = ref.read(appSettingsProvider);
    final serverUrl = settings.djangoBaseUrl;
    try {
      final api = ApiService(settings);
      await api.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        slideFromRight(const GradeSelectionScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = _parseError(e));
    } catch (e) {
      final detail = e.toString();
      setState(() => _errorMessage =
          'Cannot reach server at:\n$serverUrl\n\n'
          'Make sure Django is running and the URL is correct in Settings → Ollama Config.\n\n'
          'Detail: $detail');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(ApiException e) {
    if (e.statusCode == 401) return 'Wrong username or password.';
    if (e.statusCode == 400) {
      try {
        final body = e.body;
        if (body.contains('No active account')) return 'No account found with these details.';
      } catch (_) {}
    }
    return 'Login failed (${e.statusCode}).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PadhAiColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Logo + title
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: PadhAiColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PadhAiColors.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 40,
                      color: PadhAiColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PadhAI',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: PadhAiColors.primary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: PadhAiColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 36),

                // Username
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 12),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: PadhAiColors.primary,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Continue without login
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            slideFromRight(const GradeSelectionScreen()),
                          ),
                  child: const Text('Continue without login'),
                ),
                const SizedBox(height: 24),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: PadhAiColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () => Navigator.of(context).push(
                                slideFromRight(const RegisterScreen()),
                              ),
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: PadhAiColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).push(
                            slideFromRight(const PadhSettingsScreen()),
                          ),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('Server settings'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
