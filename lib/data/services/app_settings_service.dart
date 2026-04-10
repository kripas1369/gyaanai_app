import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _kOllamaHost = 'ollama_host';

  /// Full Ollama API base for PadhAI, e.g. `http://192.168.1.5:11434` (no trailing slash).
  static const _kPadhOllamaBaseUrl = 'padh_ollama_base_url';
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

  /// User override for PadhAI → Ollama. `null` or empty = use platform default.
  String? get padhOllamaBaseUrlOverride =>
      _prefs.getString(_kPadhOllamaBaseUrl);

  Future<void> setPadhOllamaBaseUrl(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await _prefs.remove(_kPadhOllamaBaseUrl);
    } else {
      await _prefs.setString(
        _kPadhOllamaBaseUrl,
        normalizePadhOllamaBaseUrl(value),
      );
    }
  }

  /// Ensures `http://` and no trailing slash.
  static String normalizePadhOllamaBaseUrl(String raw) {
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
  /// Default to local network IP for physical device testing.
  String get djangoBaseUrl =>
      _prefs.getString(_kDjangoBaseUrl) ?? 'http://192.168.1.69:8000';
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
}
