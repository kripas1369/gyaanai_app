/// Builds the hidden system instruction for offline Gemma model.
/// Kept as short as possible — every extra character costs prefill time on-device.
String buildPadhAiSystemPrompt({
  required int grade,
  required String subjectEnglish,
}) {
  final see = grade >= 9 ? ' (SEE prep)' : '';
  return 'You are PadhAI, AI tutor for Class $grade $subjectEnglish$see. '
      'Answer in simple Nepali then English. Use Nepal examples. '
      'Math/Science: show step-by-step solutions. Write formulas in plain text like a^2 + 2ab + b^2. '
      'Keep it short for Class $grade.';
}

/// Builds a teacher-style prompt for explaining concepts.
/// Use this for more detailed, structured explanations.
String buildTeacherPrompt({
  required int grade,
  required String subjectEnglish,
  required String question,
  String? language,
}) {
  final lang = language ?? 'Nepali and English';

  return '''
Explain this as a teacher for a grade $grade student in simple $lang.

Subject: $subjectEnglish
Question: $question

Provide:
1. Simple explanation suitable for Class $grade
2. One real-world example from Nepal
3. Key points to remember
'''.trim();
}

/// Builds a quick Q&A prompt for fast responses.
String buildQuickAnswerPrompt({
  required int grade,
  required String subjectEnglish,
  required String question,
}) {
  return '''
Class $grade $subjectEnglish question: $question

Give a brief, clear answer in simple words.
'''.trim();
}

/// Subject-specific prompt enhancers.
String getSubjectHints(String subject) {
  switch (subject.toLowerCase()) {
    case 'math':
    case 'mathematics':
    case 'optional math':
      return 'Show step-by-step calculation. Use simple numbers.';
    case 'science':
      return 'Relate to daily life in Nepal. Use simple experiments if relevant.';
    case 'english':
      return 'Explain grammar simply. Give sentence examples.';
    case 'social studies':
    case 'social':
      return 'Focus on Nepal context. Mention relevant history/geography.';
    case 'nepali':
      return 'Use proper Devanagari. Explain grammar rules simply.';
    case 'computer':
    case 'computer science':
      return 'Use simple analogies. Focus on practical understanding.';
    default:
      return '';
  }
}
