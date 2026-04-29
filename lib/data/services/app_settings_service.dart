import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _kOllamaHost = 'ollama_host';
  static const _kStudentName = 'student_name';
  static const _kStudentGrade = 'student_grade';
  static const _kOnboardingDone = 'onboarding_done';

  /// Full Ollama API base for GyaanAi, e.g. `http://192.168.1.5:11434` (no trailing slash).
  static const _kGyaanOllamaBaseUrl = 'gyaan_ollama_base_url';
  static const _kDjangoBaseUrl = 'django_base_url';
  static const _kAccessToken = 'jwt_access';
  static const _kRefreshToken = 'jwt_refresh';
  static const _kLocalGrade = 'local_grade';

  AppSettingsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsService(prefs);
  }

  String get ollamaHost =>
      _prefs.getString(_kOllamaHost) ?? '192.168.1.69:11434';
  Future<void> setOllamaHost(String v) =>
      _prefs.setString(_kOllamaHost, v.trim());

  /// User override for GyaanAi → Ollama. `null` or empty = use platform default.
  String? get gyaanOllamaBaseUrlOverride =>
      _prefs.getString(_kGyaanOllamaBaseUrl);

  Future<void> setGyaanOllamaBaseUrl(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_kGyaanOllamaBaseUrl);
    } else {
      await _prefs.setString(
        _kGyaanOllamaBaseUrl,
        normalizeGyaanOllamaBaseUrl(value),
      );
    }
  }

  /// Ensures `http://` and no trailing slash.
  static String normalizeGyaanOllamaBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Raw URL as the user typed it (stored in prefs).
  /// Empty string means not configured yet — download screen will prompt.
  static const String _kDefaultDjangoBaseUrl = String.fromEnvironment(
    'DJANGO_BASE_URL',
    // defaultValue: 'http://192.168.1.73:8080',
    defaultValue: 'https://gyaanai.sajilodera.org',

  );

  /// Django base URL for the GyaanAI backend.
  ///
  /// If the user has not overridden it yet, we default to the local backend
  /// URL so the offline download screen doesn't require URL input.
  String get djangoBaseUrl {
    final v = _prefs.getString(_kDjangoBaseUrl);
    if (v == null || v.trim().isEmpty) return _kDefaultDjangoBaseUrl;
    return v;
  }
  Future<void> setDjangoBaseUrl(String v) =>
      _prefs.setString(_kDjangoBaseUrl, v.trim());

  /// The URL that should actually be used for HTTP calls.
  /// On Android, localhost/127.0.0.1 is rewritten to 10.0.2.2 so the
  /// emulator can reach the host machine's Django server.
  String get effectiveDjangoBaseUrl {
    final raw = djangoBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return _rewriteLocalhostForAndroid(raw);
  }

  /// Rewrite a URL whose host is localhost/127.0.0.1/::1 when running
  /// on Android (emulator uses 10.0.2.2 to reach the host machine).
  static String rewriteLocalhostUrl(String url) {
    return _rewriteLocalhostForAndroid(url);
  }

  static String _rewriteLocalhostForAndroid(String url) {
    try {
      if (!Platform.isAndroid) return url;
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
        return uri.replace(host: '10.0.2.2').toString();
      }
    } catch (_) {
      // Parse failed — return as-is
    }
    return url;
  }

  String? get accessToken => _prefs.getString(_kAccessToken);
  Future<void> setAccessToken(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove(_kAccessToken);
    } else {
      await _prefs.setString(_kAccessToken, v);
    }
  }

  String? get refreshToken => _prefs.getString(_kRefreshToken);
  Future<void> setRefreshToken(String? v) async {
    if (v == null || v.isEmpty) {
      await _prefs.remove(_kRefreshToken);
    } else {
      await _prefs.setString(_kRefreshToken, v);
    }
  }

  /// Grade used when fetching topics (`/api/subjects/:id/topics/?grade=`).
  int get localGrade => _prefs.getInt(_kLocalGrade) ?? 5;
  Future<void> setLocalGrade(int v) => _prefs.setInt(_kLocalGrade, v);

  // --- Offline-first student identity (no login needed) ---

  String get studentName => _prefs.getString(_kStudentName) ?? '';
  Future<void> setStudentName(String v) => _prefs.setString(_kStudentName, v.trim());

  int get studentGrade => _prefs.getInt(_kStudentGrade) ?? 0;
  Future<void> setStudentGrade(int v) => _prefs.setInt(_kStudentGrade, v);

  bool get isOnboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> completeOnboarding() => _prefs.setBool(_kOnboardingDone, true);
}
