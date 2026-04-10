/// Nepal curriculum subjects by grade band.
class SubjectItem {
  const SubjectItem({
    required this.key,
    required this.nepali,
    required this.english,
    required this.emoji,
  });

  final String key;
  final String nepali;
  final String english;
  final String emoji;
}

List<SubjectItem> subjectsForGrade(int grade) {
  if (grade >= 1 && grade <= 3) {
    return const [
      SubjectItem(key: 'nepali', nepali: 'नेपाली', english: 'Nepali', emoji: '📚'),
      SubjectItem(key: 'math', nepali: 'गणित', english: 'Mathematics', emoji: '🔢'),
      SubjectItem(
        key: 'environment',
        nepali: 'वातावरण',
        english: 'Environment & Health',
        emoji: '🌿',
      ),
      SubjectItem(key: 'english', nepali: 'अंग्रेजी', english: 'English', emoji: '🔤'),
    ];
  }
  if (grade >= 4 && grade <= 5) {
    return const [
      SubjectItem(key: 'nepali', nepali: 'नेपाली', english: 'Nepali', emoji: '📚'),
      SubjectItem(key: 'math', nepali: 'गणित', english: 'Mathematics', emoji: '🔢'),
      SubjectItem(key: 'science', nepali: 'विज्ञान', english: 'Science', emoji: '🔬'),
      SubjectItem(
        key: 'social',
        nepali: 'सामाजिक',
        english: 'Social Studies',
        emoji: '🗺️',
      ),
      SubjectItem(key: 'english', nepali: 'अंग्रेजी', english: 'English', emoji: '🔤'),
      SubjectItem(key: 'health', nepali: 'स्वास्थ्य', english: 'Health', emoji: '💊'),
    ];
  }
  if (grade >= 6 && grade <= 8) {
    return const [
      SubjectItem(key: 'nepali', nepali: 'नेपाली', english: 'Nepali', emoji: '📚'),
      SubjectItem(key: 'math', nepali: 'गणित', english: 'Mathematics', emoji: '🔢'),
      SubjectItem(key: 'science', nepali: 'विज्ञान', english: 'Science', emoji: '🔬'),
      SubjectItem(
        key: 'social',
        nepali: 'सामाजिक',
        english: 'Social Studies',
        emoji: '🗺️',
      ),
      SubjectItem(key: 'english', nepali: 'अंग्रेजी', english: 'English', emoji: '🔤'),
      SubjectItem(
        key: 'computer',
        nepali: 'कम्प्युटर',
        english: 'Computer Science',
        emoji: '💻',
      ),
    ];
  }
  // 9–10 SEE
  return const [
    SubjectItem(
      key: 'comp_nepali',
      nepali: 'अनिवार्य नेपाली',
      english: 'Compulsory Nepali',
      emoji: '📚',
    ),
    SubjectItem(
      key: 'comp_english',
      nepali: 'अनिवार्य अंग्रेजी',
      english: 'Compulsory English',
      emoji: '🔤',
    ),
    SubjectItem(key: 'math', nepali: 'गणित', english: 'Mathematics', emoji: '🔢'),
    SubjectItem(key: 'science', nepali: 'विज्ञान', english: 'Science', emoji: '🔬'),
    SubjectItem(
      key: 'social',
      nepali: 'सामाजिक',
      english: 'Social Studies',
      emoji: '🗺️',
    ),
    SubjectItem(
      key: 'computer',
      nepali: 'कम्प्युटर',
      english: 'Computer Science',
      emoji: '💻',
    ),
    SubjectItem(
      key: 'optional_math',
      nepali: 'ऐच्छिक गणित',
      english: 'Optional Mathematics',
      emoji: '➕',
    ),
    SubjectItem(
      key: 'account',
      nepali: 'हिसाब',
      english: 'Account/Economics',
      emoji: '💰',
    ),
  ];
}

String subjectDisplayTitle(SubjectItem s) => '${s.nepali} — ${s.english}';
