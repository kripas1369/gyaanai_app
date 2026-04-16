import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/api_service.dart';
import '../../navigation/slide_route.dart';
import '../../providers/padh_ai_providers.dart';
import '../../theme/padh_ai_theme.dart';
import '../grade_selection_screen.dart';
import '../padh_settings_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  int _selectedGrade = 5;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      await api.registerStudent(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        passwordConfirm: _confirmCtrl.text,
        fullName: _fullNameCtrl.text.trim(),
        grade: _selectedGrade,
        schoolName: _schoolCtrl.text.trim(),
      );

      // Auto-login after registration
      await api.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Welcome to GyaanAi.'),
          backgroundColor: PadhAiColors.secondary,
        ),
      );
      Navigator.of(context).pushReplacement(
        slideFromRight(const GradeSelectionScreen()),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = _parseError(e));
    } catch (e) {
      setState(() =>
          _errorMessage = 'Could not connect to server. Check your URL in Settings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(ApiException e) {
    if (e.statusCode == 400) {
      final body = e.body;
      if (body.contains('username') && body.contains('already taken')) {
        return 'Username is already taken. Try another one.';
      }
      if (body.contains("don't match") || body.contains("Passwords")) {
        return 'Passwords do not match.';
      }
      if (body.contains('password')) return 'Password is too weak or invalid.';
    }
    return 'Registration failed (${e.statusCode}).';
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PadhAiColors.background,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: PadhAiColors.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Student Registration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: PadhAiColors.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill in your details to get started.',
                  style: TextStyle(color: PadhAiColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Full name
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: _inputDec('Full Name', Icons.badge_outlined),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                ),
                const SizedBox(height: 14),

                // Username
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: _inputDec('Username', Icons.person_outline_rounded),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter a username';
                    if (v.trim().length < 3) return 'Username must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Grade picker
                DropdownButtonFormField<int>(
                  initialValue: _selectedGrade,
                  decoration: _inputDec('Class / Grade', Icons.school_outlined),
                  items: List.generate(10, (i) => i + 1)
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('Class $g'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGrade = v);
                  },
                ),
                const SizedBox(height: 14),

                // School (optional)
                TextFormField(
                  controller: _schoolCtrl,
                  decoration: _inputDec(
                    'School Name (optional)',
                    Icons.account_balance_outlined,
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

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
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
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

                // Register button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _register,
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
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
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

                // Back to login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: PadhAiColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: PadhAiColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
