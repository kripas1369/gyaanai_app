/// Builds the hidden system instruction for offline Gemma model.
/// Kept as short as possible — every extra character costs prefill time on-device.
///
/// IMPORTANT: System prompt explicitly states current grade/subject to prevent
/// context bleeding from previous conversations.
String buildGyaanAiSystemPrompt({
  required int grade,
  required String subjectEnglish,
}) {
  // General mode (grade=0) - answer any question
  if (grade == 0 || subjectEnglish.toLowerCase() == 'general') {
    return '[NEW CONVERSATION] You are GyaanAi, helpful AI assistant. '
        'Ignore any previous conversation context. '
        'User may ask in English or Nepali. '
        'Reply in English only — no Devanagari. '
        'Be helpful, accurate, concise. '
        'For math: show steps + answer. '
        'For code: give working examples.';
  }

  final see = grade >= 9 ? ' (SEE prep)' : '';
  return '[NEW CONVERSATION - Class $grade $subjectEnglish] '
      'You are GyaanAi, AI tutor ONLY for Class $grade $subjectEnglish$see. '
      'Ignore any previous conversation about other subjects or grades. '
      'Student may ask in English or Nepali (or mixed). '
      'Reply in English only — no Devanagari, no Nepali sentences in your reply. '
      'Use Nepal-relevant examples when helpful. '
      'If the question is a math problem (calculation/equations), reply with ONLY math: steps + formulas + final answer (no extra prose). '
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
  final lang = language ?? 'English only (no Nepali in the reply)';

  return '''
Explain this as a teacher for a grade $grade student in simple $lang.
The student may have asked in English or Nepali.

Subject: $subjectEnglish
Question: $question

Provide:
1. Simple explanation suitable for Class $grade
2. One real-world example from Nepal
3. Key points to remember
If the question is a math problem, respond with ONLY math steps and final answer (no explanation text).
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

Give a brief, clear answer in simple English only (student may have asked in either language).
'''.trim();
}

/// One-off translation: not used for the main tutor reply (English-only there).
String buildTutorAnswerTranslationSystemPrompt() {
  return 'You translate educational tutor replies into Nepali. '
      'Output Nepali in Devanagari only. Keep math symbols, numbers, variable names, and LaTeX-style expressions in Latin. '
      'If the input is only math/steps with almost no prose, return the same text unchanged. '
      'No preamble, no English — only the translation (or unchanged math).';
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
