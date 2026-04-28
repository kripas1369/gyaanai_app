import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/services/app_settings_service.dart';
import '../providers/gyaan_ai_providers.dart';
import '../theme/gyaan_ai_theme.dart';

/// GyaanAi settings: Django API URL and Ollama host (Riverpod; no GetX).
class GyaanAiSettingsScreen extends ConsumerStatefulWidget {
  const GyaanAiSettingsScreen({super.key});

  @override
  ConsumerState<GyaanAiSettingsScreen> createState() => _GyaanAiSettingsScreenState();
}

class _GyaanAiSettingsScreenState extends ConsumerState<GyaanAiSettingsScreen> {
  late final TextEditingController _djangoCtrl;
  late final TextEditingController _ollamaCtrl;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appSettingsProvider);
    _djangoCtrl = TextEditingController(text: s.djangoBaseUrl);
    _ollamaCtrl = TextEditingController(text: s.ollamaHost);
  }

  @override
  void dispose() {
    _djangoCtrl.dispose();
    _ollamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = ref.read(appSettingsProvider);
    await settings.setDjangoBaseUrl(_djangoCtrl.text.trim());
    await settings.setOllamaHost(_ollamaCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _testDjango() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final raw = _djangoCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    final base = AppSettingsService.rewriteLocalhostUrl(raw);
    final uri = Uri.parse('$base/api/health/');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult =
            r.statusCode >= 200 && r.statusCode < 300 ? 'OK (${r.statusCode})' : 'HTTP ${r.statusCode}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testResult = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GyaanAiColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: GyaanAiColors.background,
        foregroundColor: GyaanAiColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Server',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: GyaanAiColors.primary,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _djangoCtrl,
            decoration: const InputDecoration(
              labelText: 'Django base URL',
              hintText: 'http://192.168.1.x:8000',
              border: OutlineInputBorder(),
              helperText: 'Same Wi‑Fi as this device; no trailing slash',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ollamaCtrl,
            decoration: const InputDecoration(
              labelText: 'Ollama server (host:port)',
              hintText: '192.168.1.x:11434',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: GyaanAiColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testDjango,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('Test Django connection'),
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Text(
              _testResult!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _testResult!.startsWith('OK')
                        ? GyaanAiColors.secondary
                        : Colors.red,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
