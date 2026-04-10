import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/services/app_settings_service.dart';
import 'data/services/local_db_service.dart';
import 'padh_ai/providers/padh_ai_providers.dart';
import 'padh_ai/screens/splash_screen.dart';
import 'padh_ai/theme/padh_ai_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load shared preferences and database (fast operations)
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettingsService(prefs);
  final db = await LocalDbService.open();

  // Initialize FlutterGemma in background (don't block app startup)
  FlutterGemma.initialize().catchError((e) {
    // Ignore initialization errors - will handle in splash screen
  });

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(db),
        appSettingsProvider.overrideWithValue(settings),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const GyaanApp(),
    ),
  );
}

class GyaanApp extends StatelessWidget {
  const GyaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PadhAI',
      theme: padhAiLightTheme(),
      darkTheme: padhAiDarkTheme(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
