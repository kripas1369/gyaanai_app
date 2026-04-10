import '../../data/services/local_db_service.dart';

class PadhAiChatRepository {
  PadhAiChatRepository(this._db);

  final LocalDbService _db;

  Future<int> createEmptySession({
    required int grade,
    required String subjectKey,
  }) {
    final now = DateTime.now();
    return _db.insertChatSession(
      grade: grade,
      subject: subjectKey,
      title: 'New chat',
      createdAt: now,
      lastMessageAt: now,
    );
  }

  Future<void> updateSessionTitle(int sessionId, String title) {
    return _db.updateChatSessionTitle(sessionId, title);
  }

  Future<void> touchSession(int sessionId) {
    return _db.updateChatSessionLastMessageAt(sessionId, DateTime.now());
  }

  Future<List<Map<String, Object?>>> sessionsForGradeSubject(
    int grade,
    String subjectKey,
  ) {
    return _db.getChatSessionsForGradeSubject(grade, subjectKey);
  }

  Future<List<Map<String, Object?>>> messagesForSession(int sessionId) {
    return _db.getMessagesForSession(sessionId);
  }

  Future<int> insertUserMessage(int sessionId, String content) async {
    final id = await _db.insertChatMessage(
      sessionId: sessionId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    await touchSession(sessionId);
    return id;
  }

  Future<int> insertAssistantMessage(int sessionId, String content) async {
    final id = await _db.insertChatMessage(
      sessionId: sessionId,
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
    await touchSession(sessionId);
    return id;
  }

  Future<void> clearMessages(int sessionId) {
    return _db.deleteMessagesForSession(sessionId);
  }

  Future<String?> lastPreview(int sessionId) {
    return _db.getLastMessagePreview(sessionId);
  }
}
