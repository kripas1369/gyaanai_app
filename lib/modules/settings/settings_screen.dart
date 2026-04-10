import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/services/app_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _settings = Get.find<AppSettingsService>();
  late int _grade = _settings.localGrade;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Grade for curriculum sync'),
            subtitle: Text('Topics are filtered by grade ($_grade)'),
            trailing: DropdownButton<int>(
              value: _grade,
              items: [
                for (var g = 1; g <= 10; g++)
                  DropdownMenuItem(value: g, child: Text('$g')),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _grade = v);
                await _settings.setLocalGrade(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Ollama & Django'),
            subtitle: const Text('Server URLs and connection test'),
            onTap: () => Get.toNamed(AppRoutes.ollamaConfig),
          ),
        ],
      ),
    );
  }
}
