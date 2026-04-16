import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite cache mirroring Django curriculum payloads for offline use.
class LocalDbService {
  LocalDbService(this._db);

  final Database _db;

  static const _version = 2;

  static Future<LocalDbService> open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'gyaanai.db');
    final db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE subjects (
  id INTEGER PRIMARY KEY,
  json TEXT NOT NULL,
  synced_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE topics (
  id INTEGER PRIMARY KEY,
  subject_id INTEGER NOT NULL,
  json TEXT NOT NULL,
  synced_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE lesson_list (
  topic_id INTEGER NOT NULL,
  lesson_id INTEGER NOT NULL,
  json TEXT NOT NULL,
  PRIMARY KEY (topic_id, lesson_id)
)''');
        await db.execute('''
CREATE TABLE lesson_detail (
  lesson_id INTEGER PRIMARY KEY,
  json TEXT NOT NULL,
  synced_at INTEGER NOT NULL
)''');
        await db.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at INTEGER NOT NULL
)''');
        await db.execute(
          'CREATE INDEX idx_topics_subject ON topics(subject_id)',
        );
        await _createPadhAiChatTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPadhAiChatTables(db);
        }
      },
    );
    return LocalDbService(db);
  }

  static Future<void> _createPadhAiChatTables(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS chat_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  grade INTEGER NOT NULL,
  subject TEXT NOT NULL,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_message_at TEXT NOT NULL
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (session_id) REFERENCES chat_sessions (id) ON DELETE CASCADE
)''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id)',
    );
  }

  // --- GyaanAi chat (grade + subject tutoring) ---

  Future<int> insertChatSession({
    required int grade,
    required String subject,
    required String title,
    required DateTime createdAt,
    required DateTime lastMessageAt,
  }) async {
    return _db.insert('chat_sessions', {
      'grade': grade,
      'subject': subject,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt.toIso8601String(),
    });
  }

  Future<void> updateChatSessionTitle(int sessionId, String title) async {
    await _db.update(
      'chat_sessions',
      {'title': title},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> updateChatSessionLastMessageAt(
    int sessionId,
    DateTime at,
  ) async {
    await _db.update(
      'chat_sessions',
      {'last_message_at': at.toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, Object?>>> getChatSessionsForGradeSubject(
    int grade,
    String subject,
  ) async {
    return _db.query(
      'chat_sessions',
      where: 'grade = ? AND subject = ?',
      whereArgs: [grade, subject],
      orderBy: 'last_message_at DESC',
    );
  }

  Future<int> insertChatMessage({
    required int sessionId,
    required String role,
    required String content,
    required DateTime createdAt,
  }) async {
    return _db.insert('messages', {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getMessagesForSession(int sessionId) async {
    return _db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<String?> getLastMessagePreview(int sessionId) async {
    final rows = await _db.query(
      'messages',
      columns: ['content'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['content'] as String?;
  }

  Future<void> deleteMessagesForSession(int sessionId) async {
    await _db.delete(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteChatSession(int sessionId) async {
    await _db.delete(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await _db.delete(
      'chat_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> clearCurriculumCache() async {
    await _db.delete('lesson_detail');
    await _db.delete('lesson_list');
    await _db.delete('topics');
    await _db.delete('subjects');
  }

  Future<void> upsertSubjects(List<Map<String, dynamic>> rows) async {
    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final m in rows) {
      final id = m['id'] as int;
      batch.insert(
        'subjects',
        {'id': id, 'json': jsonEncode(m), 'synced_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    final rows = await _db.query('subjects', orderBy: 'id ASC');
    return rows
        .map((r) => jsonDecode(r['json']! as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertTopics(int subjectId, List<Map<String, dynamic>> rows) async {
    final batch = _db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.delete('topics', where: 'subject_id = ?', whereArgs: [subjectId]);
    for (final m in rows) {
      final id = m['id'] as int;
      batch.insert(
        'topics',
        {'id': id, 'subject_id': subjectId, 'json': jsonEncode(m), 'synced_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getTopicsForSubject(int subjectId) async {
    final rows = await _db.query(
      'topics',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'id ASC',
    );
    return rows
        .map((r) => jsonDecode(r['json']! as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertLessonList(
    int topicId,
    List<Map<String, dynamic>> lessons,
  ) async {
    final batch = _db.batch();
    await _db.delete('lesson_list', where: 'topic_id = ?', whereArgs: [topicId]);
    for (final m in lessons) {
      final id = m['id'] as int;
      batch.insert('lesson_list', {
        'topic_id': topicId,
        'lesson_id': id,
        'json': jsonEncode(m),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLessonsForTopic(int topicId) async {
    final rows = await _db.query(
      'lesson_list',
      where: 'topic_id = ?',
      whereArgs: [topicId],
      orderBy: 'lesson_id ASC',
    );
    return rows
        .map((r) => jsonDecode(r['json']! as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertLessonDetail(Map<String, dynamic> detail) async {
    final id = detail['id'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      'lesson_detail',
      {'lesson_id': id, 'json': jsonEncode(detail), 'synced_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLessonDetail(int lessonId) async {
    final rows = await _db.query(
      'lesson_detail',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['json']! as String) as Map<String, dynamic>;
  }

  Future<void> enqueueSync(String kind, Map<String, dynamic> payload) async {
    await _db.insert('sync_queue', {
      'kind': kind,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
