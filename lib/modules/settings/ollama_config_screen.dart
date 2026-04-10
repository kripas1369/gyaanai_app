import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/controllers/connectivity_controller.dart';
import '../../data/services/app_settings_service.dart';

class OllamaConfigScreen extends StatefulWidget {
  const OllamaConfigScreen({super.key});

  @override
  State<OllamaConfigScreen> createState() => _OllamaConfigScreenState();
}

class _OllamaConfigScreenState extends State<OllamaConfigScreen> {
  late final _settings = Get.find<AppSettingsService>();
  late final _connectivity = Get.find<ConnectivityController>();

  late final _host = TextEditingController(text: _settings.ollamaHost);
  late final _django = TextEditingController(text: _settings.djangoBaseUrl);

  @override
  void dispose() {
    _host.dispose();
    _django.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ollama')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _host,
            decoration: const InputDecoration(
              labelText: 'Ollama server (host:port)',
              hintText: '127.0.0.1:11434 or 192.168.1.100:11434',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _settings.setOllamaHost(v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _django,
            decoration: const InputDecoration(
              labelText: 'Django base URL',
              hintText: 'http://127.0.0.1:8000',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => _settings.setDjangoBaseUrl(v),
          ),
          const SizedBox(height: 12),
          Obx(
            () => FilledButton.icon(
              onPressed:
                  _connectivity.isChecking.value ? null : _connectivity.manualRefresh,
              icon: _connectivity.isChecking.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Test connection'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Teacher setup (quick):\n'
            '- Install Ollama on a laptop\n'
            '- Run it on the same Wi‑Fi as students\n'
            '- Put that laptop IP above (e.g., 192.168.x.x:11434)',
          ),
        ],
      ),
    );
  }
}
