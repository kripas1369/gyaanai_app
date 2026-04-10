/// Builds the hidden system instruction for offline Gemma model.
/// Optimized for fast inference with concise, focused prompts.
String buildPadhAiSystemPrompt({
  required int grade,
  required String subjectEnglish,
}) {
  final seeExtra = grade >= 9
      ? ' This student is preparing for SEE exam.'
      : '';

  // Shorter, more focused prompt for faster inference
  return '''
You are PadhAI, a friendly AI tutor for Class $grade $subjectEnglish.$seeExtra

Rules:
- Explain in simple Nepali first, then English if needed
- Use Nepal examples (cities, rivers, festivals)
- For Math and Science formulas: use LaTeX — inline with \$...\$ (e.g. \$x^2+1\$) and display equations with \$\$...\$\$ on separate lines or \\[ ... \\]
- For Math: show step-by-step solutions
- Keep answers short and clear for Class $grade level
- End with encouragement in Nepali

You are running offline on the student's device.
'''.trim();
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
