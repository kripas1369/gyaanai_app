import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_settings_service.dart';

/// HTTP client for `gyaanai_backend` (Django REST + JWT).
///
/// Public curriculum routes match `config/api_urls.py`:
/// - `GET /api/subjects/`
/// - `GET /api/subjects/:id/topics/?grade=`
/// - `GET /api/topics/:id/lessons/`
/// - `GET /api/curriculum/lessons/:id/` (full lesson body)
class ApiService {
  ApiService(this._settings);

  final AppSettingsService _settings;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = _settings.effectiveDjangoBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse(base + p).replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = _settings.accessToken;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic> && decoded['results'] is List) {
      return decoded['results'] as List<dynamic>;
    }
    throw FormatException('Expected JSON list or paginated results: $body');
  }

  Future<List<Map<String, dynamic>>> getSubjects() async {
    final r = await http.get(_uri('/api/subjects/'), headers: _headers());
    _throwIfBad(r);
    return _decodeList(r.body).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTopicsForSubject(
    int subjectId, {
    required int grade,
  }) async {
    final r = await http.get(
      _uri('/api/subjects/$subjectId/topics/', {'grade': '$grade'}),
      headers: _headers(),
    );
    _throwIfBad(r);
    return _decodeList(r.body).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getLessonsForTopic(int topicId) async {
    final r = await http.get(
      _uri('/api/topics/$topicId/lessons/'),
      headers: _headers(),
    );
    _throwIfBad(r);
    return _decodeList(r.body).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getLessonDetail(int lessonId) async {
    final r = await http.get(
      _uri('/api/curriculum/lessons/$lessonId/'),
      headers: _headers(),
    );
    _throwIfBad(r);
    final decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Expected lesson object');
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final r = await http.post(
      _uri('/api/auth/login/'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({'username': username, 'password': password}),
    );
    _throwIfBad(r);
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    final access = m['access'] as String?;
    final refresh = m['refresh'] as String?;
    if (access != null) await _settings.setAccessToken(access);
    if (refresh != null) await _settings.setRefreshToken(refresh);
    return m;
  }

  /// Register a new student. Required: [username], [password], [passwordConfirm],
  /// [fullName], [grade]. Optional: [schoolName], [district].
  Future<Map<String, dynamic>> registerStudent({
    required String username,
    required String password,
    required String passwordConfirm,
    required String fullName,
    required int grade,
    String schoolName = '',
    String district = '',
  }) async {
    final r = await http.post(
      _uri('/api/auth/register/'),
      headers: _headers(jsonBody: true),
      body: jsonEncode({
        'role': 'student',
        'username': username,
        'password': password,
        'password_confirm': passwordConfirm,
        'full_name': fullName,
        'grade': grade,
        if (schoolName.isNotEmpty) 'school_name': schoolName,
        if (district.isNotEmpty) 'district': district,
      }),
    );
    _throwIfBad(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _settings.setAccessToken(null);
    await _settings.setRefreshToken(null);
  }

  /// Current user profile (`GET /api/profile/`). Requires a valid access token.
  Future<Map<String, dynamic>> getProfile() async {
    final r = await http.get(_uri('/api/profile/'), headers: _headers());
    _throwIfBad(r);
    final decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Expected profile object');
  }

  void _throwIfBad(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw ApiException(r.statusCode, r.body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
