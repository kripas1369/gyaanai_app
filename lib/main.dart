import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/services/app_settings_service.dart';
import 'data/services/local_db_service.dart';
import 'padh_ai/providers/padh_ai_providers.dart';
import 'padh_ai/screens/splash_screen.dart';
import 'padh_ai/theme/padh_ai_theme.dart';

/// Global container reference for memory pressure handling
ProviderContainer? _globalContainer;

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

  // Create container with memory pressure handling
  final container = ProviderContainer(
    overrides: [
      localDbProvider.overrideWithValue(db),
      appSettingsProvider.overrideWithValue(settings),
      sharedPrefsProvider.overrideWithValue(prefs),
    ],
  );
  _globalContainer = container;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const GyaanApp(),
    ),
  );
}

class GyaanApp extends StatefulWidget {
  const GyaanApp({super.key});

  @override
  State<GyaanApp> createState() => _GyaanAppState();
}

class _GyaanAppState extends State<GyaanApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Handle memory pressure from system (critical for 2GB RAM devices)
  @override
  void didHaveMemoryPressure() {
    debugPrint('GyaanApp: Memory pressure detected, releasing AI resources');
    // Release AI model to free memory
    final container = _globalContainer;
    if (container != null) {
      try {
        final hybridService = container.read(hybridAiProvider);
        hybridService.releaseForMemoryPressure();
      } catch (e) {
        debugPrint('GyaanApp: Error releasing AI resources: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GyaanAi',
      theme: padhAiLightTheme(),
      darkTheme: padhAiDarkTheme(),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
