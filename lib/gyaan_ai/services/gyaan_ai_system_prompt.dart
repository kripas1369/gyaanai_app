/// Builds the hidden system instruction for offline Gemma model.
/// Kept as short as possible — every extra character costs prefill time on-device.
///
/// IMPORTANT: System prompt explicitly states current grade/subject to prevent
/// context bleeding from previous conversations.
String buildGyaanAiSystemPrompt({
  required int grade,
  required String subjectEnglish,
  bool hasImage = false,
}) {
  // General mode (grade=0) - answer any question
  if (grade == 0 || subjectEnglish.toLowerCase() == 'general') {
    final imgNote = hasImage
        ? 'An image has been attached — analyze it carefully and answer based on what you see. '
        : '';
    return '[NEW CONVERSATION] You are GyaanAi, helpful AI assistant for students in Nepal. '
        '$imgNote'
        'Ignore any previous conversation context. '
        'User may ask in English or Nepali. '
        'Reply in English only — no Devanagari. '
        'Be helpful, accurate, concise. '
        'For math: show steps + answer. '
        'For code: give working examples.';
  }

  final see = grade >= 9 ? ' (SEE prep — secondary education exam)' : '';
  final subjectHints = getSubjectHints(subjectEnglish);
  final imgInstruction = hasImage
      ? 'An image has been attached — read/analyze it carefully. If it contains a question or math problem, solve it step by step. '
      : '';

  return '[NEW CONVERSATION - Class $grade $subjectEnglish] '
      'You are GyaanAi, AI tutor ONLY for Class $grade $subjectEnglish$see following Nepal National Curriculum Framework (NCF). '
      'Ignore any previous conversation about other subjects or grades. '
      '$imgInstruction'
      'Student may ask in English or Nepali (or mixed). '
      'Reply in English only — no Devanagari in your reply. '
      'Use Nepal-relevant examples (Kathmandu, Narayani river, Mt. Everest, local context). '
      '${subjectHints.isNotEmpty ? "$subjectHints " : ""}'
      'If the question is a math problem: reply with ONLY math steps + formulas + answer (no prose). '
      'Keep answers appropriate for Class $grade level. '
      'For SEE preparation: focus on exam-likely questions and scoring methods.';
}

/// Quick suggestion prompts for each subject to show in empty chat state
List<String> getSubjectSuggestions(int grade, String subjectKey) {
  switch (subjectKey.toLowerCase()) {
    case 'math':
    case 'mathematics':
      if (grade <= 5) {
        return [
          'What is 345 × 12?',
          'Explain fractions with an example',
          'How do I find the area of a rectangle?',
          'What are multiples and factors?',
        ];
      }
      if (grade <= 8) {
        return [
          'Solve: 2x + 5 = 13',
          'Find the HCF and LCM of 12 and 18',
          'Explain Pythagoras theorem with example',
          'How to calculate percentage?',
        ];
      }
      return [
        'Solve quadratic equation: x² - 5x + 6 = 0',
        'Prove: sin²θ + cos²θ = 1',
        'Find the area under a curve',
        'Explain coordinate geometry basics',
      ];

    case 'science':
      if (grade <= 5) {
        return [
          'What are the states of matter?',
          'How do plants make food?',
          'What is the water cycle?',
          'Name the planets in our solar system',
        ];
      }
      if (grade <= 8) {
        return [
          'Explain photosynthesis step by step',
          'What is Newton\'s second law?',
          'How does the human digestive system work?',
          'What are acids and bases?',
        ];
      }
      return [
        'Explain chemical bonding (ionic vs covalent)',
        'What is Ohm\'s law? Give an example.',
        'Explain DNA structure and function',
        'What are Newton\'s laws of motion?',
      ];

    case 'nepali':
    case 'comp_nepali':
    case 'compulsory nepali':
      return [
        'नेपाली व्याकरण: कारक भनेको के हो?',
        'निबन्ध कसरी लेख्ने?',
        'Explain the difference between तत्सम and तद्भव words',
        'What is अनुच्छेद लेखन?',
      ];

    case 'english':
    case 'comp_english':
    case 'compulsory english':
      if (grade <= 5) {
        return [
          'What are nouns and pronouns?',
          'How to write a simple paragraph?',
          'Explain present tense with examples',
          'What are adjectives?',
        ];
      }
      return [
        'Explain active and passive voice with examples',
        'What is the difference between since and for?',
        'How to write a formal letter?',
        'Explain reported speech rules',
      ];

    case 'social':
    case 'social studies':
      if (grade <= 5) {
        return [
          'What are the provinces of Nepal?',
          'Who was Prithvi Narayan Shah?',
          'What are natural resources?',
          'Explain the water cycle',
        ];
      }
      return [
        'Explain Nepal\'s federal structure',
        'What was the impact of 2015 earthquake in Nepal?',
        'Describe the geography of Nepal (Himalayan, Hilly, Terai)',
        'What is democracy and how does it work in Nepal?',
      ];

    case 'computer':
    case 'computer science':
      return [
        'What is RAM and ROM?',
        'Explain how the internet works',
        'What is a database? Give an example.',
        'Write a simple program in Python',
      ];

    case 'optional_math':
    case 'optional mathematics':
      return [
        'Solve: ∫(2x + 3)dx',
        'Find the determinant of a 2×2 matrix',
        'Explain limit and continuity',
        'What is differential calculus?',
      ];

    case 'health':
      return [
        'What is a balanced diet?',
        'How to prevent common diseases in Nepal?',
        'Explain personal hygiene habits',
        'What are the effects of malnutrition?',
      ];

    default:
      return [
        'Explain the main topic in this subject',
        'Give me practice questions for Class $grade',
        'What should I study for the exam?',
        'Help me understand this concept',
      ];
  }
}

/// Builds a teacher-style prompt for explaining concepts.
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
    case 'optional mathematics':
      return 'Show step-by-step calculation. Use simple numbers. '
          'Format equations clearly. Label each step.';
    case 'science':
      return 'Relate to daily life in Nepal. Use simple experiments if relevant. '
          'Connect to Nepal\'s geography/environment where possible.';
    case 'english':
    case 'compulsory english':
      return 'Explain grammar simply with rules + examples. '
          'For writing tasks, give a structured template.';
    case 'social studies':
    case 'social':
      return 'Focus on Nepal context first. '
          'Mention relevant Nepali history, geography, and governance. '
          'Use districts, rivers, and mountains from Nepal as examples.';
    case 'nepali':
    case 'compulsory nepali':
      return 'Use proper Devanagari for Nepali words when explaining. '
          'Explain grammar rules with examples from standard Nepali textbooks.';
    case 'computer':
    case 'computer science':
      return 'Use simple analogies. Focus on practical understanding. '
          'For programming: show working code examples.';
    case 'health':
      return 'Focus on practical health tips relevant to Nepal\'s context. '
          'Mention local foods, diseases common in Nepal, and prevention.';
    default:
      return '';
  }
}
