/// Nepal Curriculum Model Questions
/// Covers SEE (Grade 10), Secondary (8-9), Middle (6-7), and Primary (4-5).
/// Questions follow Nepal's National Curriculum Framework (NCF) and SEE exam patterns.
library;

enum QuestionType { mcq, shortAnswer, longAnswer }

class ModelQuestion {
  final String id;
  final int grade; // 0 = all grades in band
  final int gradeBandMin;
  final int gradeBandMax;
  final String subjectKey; // matches SubjectItem.key
  final String chapter;
  final String question;
  final QuestionType type;
  final List<String>? options; // A, B, C, D for MCQ
  final String? answer;
  final int marks;
  final int? year; // SEE year, null = practice question

  const ModelQuestion({
    required this.id,
    required this.gradeBandMin,
    required this.gradeBandMax,
    required this.subjectKey,
    required this.chapter,
    required this.question,
    required this.type,
    this.options,
    this.answer,
    required this.marks,
    this.year,
  }) : grade = gradeBandMin;

  bool matchesGrade(int g) => g >= gradeBandMin && g <= gradeBandMax;
  bool matchesSubject(String key) => subjectKey == key;

  String get typeLabel => switch (type) {
    QuestionType.mcq => 'MCQ',
    QuestionType.shortAnswer => 'Short Answer',
    QuestionType.longAnswer => 'Long Answer',
  };

  String get marksLabel => '$marks Mark${marks == 1 ? '' : 's'}';

  /// Prompt to send to AI for explanation
  String toAiPrompt(int grade, String subject) {
    if (type == QuestionType.mcq && options != null) {
      final opts = options!.asMap().entries.map((e) {
        final label = String.fromCharCode(65 + e.key);
        return '$label) ${e.value}';
      }).join('\n');
      return 'Solve this Class $grade $subject MCQ question step by step and explain why the correct answer is right:\n\n$question\n\n$opts\n\nShow the reasoning clearly.';
    }
    if (type == QuestionType.longAnswer) {
      return 'Solve this Class $grade $subject question completely with all working and explanation:\n\n$question\n\nProvide a full, detailed answer suitable for a board exam.';
    }
    return 'Solve this Class $grade $subject question with clear steps:\n\n$question\n\nExplain each step so a student can understand.';
  }
}

// ─── SEE / GRADE 10 ───────────────────────────────────────────────────────────

const _seeMath = [
  ModelQuestion(
    id: 'see_math_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Algebra', year: 2023,
    question: 'Solve the quadratic equation: x² - 7x + 12 = 0',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'x = 3 or x = 4',
  ),
  ModelQuestion(
    id: 'see_math_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Commercial Math', year: 2023,
    question: 'A shopkeeper marks a radio at Rs. 4,500. He allows a 10% discount and still earns a 25% profit. Find the cost price of the radio.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'Cost price = Rs. 3,240',
  ),
  ModelQuestion(
    id: 'see_math_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Sets', year: 2022,
    question: 'In a class of 50 students, 30 like Mathematics, 25 like Science, and 10 like both subjects. Using a Venn diagram, find: (i) how many like only Mathematics, (ii) how many like only Science, (iii) how many like neither subject.',
    type: QuestionType.longAnswer, marks: 6,
  ),
  ModelQuestion(
    id: 'see_math_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Statistics', year: 2023,
    question: 'Find the mean of the following data:\n\nMarks: 10, 20, 30, 40, 50\nFrequency: 3, 5, 8, 6, 3',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'see_math_05', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Trigonometry',
    question: 'If sin θ = 5/13, find the values of cos θ and tan θ.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'cos θ = 12/13, tan θ = 5/12',
  ),
  ModelQuestion(
    id: 'see_math_06', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Mensuration', year: 2022,
    question: 'The radius of a circular field is 35 m. Find: (i) the circumference (ii) the area. (Use π = 22/7)',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'see_math_07', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Trigonometry', year: 2023,
    question: 'From a point on the ground, the angle of elevation of the top of a tower is 45°. If the tower is 50 m high, find the distance of the point from the base of the tower.',
    type: QuestionType.longAnswer, marks: 6,
    answer: 'Distance = 50 m',
  ),
  ModelQuestion(
    id: 'see_math_08', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Algebra',
    question: 'Which of the following is a root of 2x² - 5x + 3 = 0?',
    type: QuestionType.mcq, marks: 1,
    options: ['x = 1', 'x = 3/2', 'x = 2', 'x = -1'],
    answer: 'A and B (x = 1 and x = 3/2)',
  ),
  ModelQuestion(
    id: 'see_math_09', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Commercial Math',
    question: 'VAT rate in Nepal is:',
    type: QuestionType.mcq, marks: 1,
    options: ['10%', '13%', '15%', '12%'],
    answer: '13%',
  ),
  ModelQuestion(
    id: 'see_math_10', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'math',
    chapter: 'Geometry', year: 2022,
    question: 'Prove that the sum of all angles in a triangle is 180°.',
    type: QuestionType.longAnswer, marks: 5,
  ),
];

const _seeScience = [
  ModelQuestion(
    id: 'see_sci_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Electricity', year: 2023,
    question: 'An electric bulb of 100W is connected to a 220V supply. Calculate: (i) the resistance of the bulb (ii) the current flowing through it.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'R = 484Ω, I = 0.45A',
  ),
  ModelQuestion(
    id: 'see_sci_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Electricity', year: 2022,
    question: 'Three resistors of 3Ω, 6Ω, and 9Ω are connected in parallel. Calculate the equivalent resistance of the combination.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'R_eq = 18/11 ≈ 1.64Ω',
  ),
  ModelQuestion(
    id: 'see_sci_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Human Biology',
    question: 'Write the chemical equation for photosynthesis. Name the raw materials and products.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: '6CO₂ + 6H₂O → C₆H₁₂O₆ + 6O₂ (in presence of light and chlorophyll)',
  ),
  ModelQuestion(
    id: 'see_sci_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Light', year: 2023,
    question: 'State Snell\'s law of refraction. A ray of light passes from air into water. If the angle of incidence is 30° and the refractive index of water is 4/3, find the angle of refraction.',
    type: QuestionType.longAnswer, marks: 6,
  ),
  ModelQuestion(
    id: 'see_sci_05', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Genetics',
    question: 'The unit of heredity is:',
    type: QuestionType.mcq, marks: 1,
    options: ['Chromosome', 'Gene', 'DNA', 'Cell'],
    answer: 'Gene',
  ),
  ModelQuestion(
    id: 'see_sci_06', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Human Biology', year: 2022,
    question: 'Explain the process of digestion of food in the human body, starting from the mouth to the small intestine.',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_sci_07', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Electricity',
    question: 'State Ohm\'s law. A wire of resistance 5Ω carries a current of 2A. Calculate the voltage across it and the power dissipated.',
    type: QuestionType.shortAnswer, marks: 5,
    answer: 'V = 10V, P = 20W',
  ),
  ModelQuestion(
    id: 'see_sci_08', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'science',
    chapter: 'Environment',
    question: 'What are the main causes of air pollution in Nepal? Suggest three ways to control it.',
    type: QuestionType.shortAnswer, marks: 4,
  ),
];

const _seeSocial = [
  ModelQuestion(
    id: 'see_social_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Nepal Geography',
    question: 'The height of Mt. Everest (Sagarmatha) as officially measured in 2020 is:',
    type: QuestionType.mcq, marks: 1,
    options: ['8,848 m', '8,849 m', '8,848.86 m', '8,850 m'],
    answer: '8,848.86 m',
  ),
  ModelQuestion(
    id: 'see_social_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Nepal Constitution',
    question: 'Nepal\'s current constitution was promulgated in:',
    type: QuestionType.mcq, marks: 1,
    options: ['2072 BS (2015 AD)', '2073 BS (2016 AD)', '2070 BS (2013 AD)', '2074 BS (2017 AD)'],
    answer: '2072 BS (2015 AD)',
  ),
  ModelQuestion(
    id: 'see_social_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Nepal Geography',
    question: 'Name the three physiographic regions of Nepal. Describe the characteristics of each region with examples of major rivers and cities.',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_social_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Nepal History', year: 2023,
    question: 'Explain the role of Prithvi Narayan Shah in the unification of Nepal. What was his strategy and what challenges did he face?',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_social_05', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Provinces of Nepal',
    question: 'Name all seven provinces of Nepal and write the capital (headquarters) of each.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'see_social_06', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Democracy & Governance',
    question: 'What is federalism? Explain the advantages of the federal system of government with examples from Nepal.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'see_social_07', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'social',
    chapter: 'Nepal Economy',
    question: 'What are the major sources of foreign currency earnings for Nepal? Explain the role of remittance in Nepal\'s economy.',
    type: QuestionType.shortAnswer, marks: 4,
  ),
];

const _seeEnglish = [
  ModelQuestion(
    id: 'see_eng_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Grammar - Voice', year: 2023,
    question: 'Change the following sentences into Passive Voice:\n(a) Ram is reading a book.\n(b) The teacher punished the student.\n(c) They will build a new hospital.',
    type: QuestionType.shortAnswer, marks: 3,
  ),
  ModelQuestion(
    id: 'see_eng_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Grammar - Reported Speech', year: 2022,
    question: 'Change into Indirect Speech:\n(a) She said, "I am very tired."\n(b) He said to me, "Where do you live?"\n(c) The teacher said, "Work hard."',
    type: QuestionType.shortAnswer, marks: 3,
  ),
  ModelQuestion(
    id: 'see_eng_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Writing - Formal Letter', year: 2023,
    question: 'Write a formal letter to the Principal of your school requesting permission to organize a Science Exhibition. Your letter should include: purpose of the event, date and venue, and how it benefits students.',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_eng_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Writing - Essay', year: 2022,
    question: 'Write an essay on "The Importance of Education for the Development of Nepal" in about 200 words.',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_eng_05', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Grammar - Tense',
    question: 'Fill in the blanks with the correct form of the verb:\n(a) She ____ (work) here since 2020.\n(b) By the time he arrived, we ____ (finish) dinner.\n(c) The children ____ (play) football right now.',
    type: QuestionType.shortAnswer, marks: 3,
  ),
  ModelQuestion(
    id: 'see_eng_06', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'english',
    chapter: 'Grammar - Preposition',
    question: 'He has been living in Kathmandu ____ five years.',
    type: QuestionType.mcq, marks: 1,
    options: ['since', 'for', 'from', 'during'],
    answer: 'for',
  ),
];

const _seeNepali = [
  ModelQuestion(
    id: 'see_nep_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'nepali',
    chapter: 'व्याकरण — कारक',
    question: 'कारक भनेको के हो? नेपाली भाषाका सातवटा कारकहरूको नाम र उदाहरण लेख्नुस्।',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'see_nep_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'nepali',
    chapter: 'लेखन — निबन्ध', year: 2023,
    question: '"पर्यावरण प्रदूषण र यसको समाधान" विषयमा एक निबन्ध लेख्नुस्। (लगभग २०० शब्द)',
    type: QuestionType.longAnswer, marks: 10,
  ),
  ModelQuestion(
    id: 'see_nep_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'nepali',
    chapter: 'व्याकरण — समास',
    question: 'निम्न शब्दहरूको समास विग्रह गर्नुस् र समासको नाम लेख्नुस्:\n(क) राम-लक्ष्मण\n(ख) त्रिभुवन\n(ग) नीलकण्ठ',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'see_nep_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'nepali',
    chapter: 'लेखन — पत्र', year: 2022,
    question: 'आफ्नो साथीलाई नेपालको प्राकृतिक सौन्दर्यको बारेमा जानकारी दिँदै एक पत्र लेख्नुस्।',
    type: QuestionType.longAnswer, marks: 8,
  ),
  ModelQuestion(
    id: 'see_nep_05', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'nepali',
    chapter: 'व्याकरण — वाच्य',
    question: 'निम्न वाक्यहरूलाई कर्मवाच्यमा परिणत गर्नुस्:\n(क) रामले किताब पढ्छ।\n(ख) सीताले खाना पकाउँछे।',
    type: QuestionType.shortAnswer, marks: 3,
  ),
];

const _seeOptMath = [
  ModelQuestion(
    id: 'see_optmath_01', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'opt_math',
    chapter: 'Calculus', year: 2023,
    question: 'Differentiate with respect to x: y = 3x³ - 5x² + 7x - 2',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'dy/dx = 9x² - 10x + 7',
  ),
  ModelQuestion(
    id: 'see_optmath_02', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'opt_math',
    chapter: 'Integration',
    question: 'Evaluate: ∫(2x + 3) dx',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'x² + 3x + C',
  ),
  ModelQuestion(
    id: 'see_optmath_03', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'opt_math',
    chapter: 'Matrix',
    question: 'If A = [[2, 3], [1, 4]], find the determinant of A and the inverse of A.',
    type: QuestionType.shortAnswer, marks: 5,
    answer: 'det(A) = 5, A⁻¹ = (1/5)[[4, -3], [-1, 2]]',
  ),
  ModelQuestion(
    id: 'see_optmath_04', gradeBandMin: 10, gradeBandMax: 10, subjectKey: 'opt_math',
    chapter: 'Coordinate Geometry',
    question: 'Find the equation of a line passing through points (2, 3) and (5, 9).',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'y = 2x - 1',
  ),
];

// ─── SECONDARY — GRADES 8-9 ────────────────────────────────────────────────

const _sec89Math = [
  ModelQuestion(
    id: 'sec_math_01', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Algebra',
    question: 'Simplify: (3x² - 2x + 1) + (x² + 5x - 4)',
    type: QuestionType.shortAnswer, marks: 3,
    answer: '4x² + 3x - 3',
  ),
  ModelQuestion(
    id: 'sec_math_02', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Commercial Math',
    question: 'A bicycle is bought for Rs. 8,000 and sold for Rs. 9,200. Find the profit percentage.',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'Profit% = 15%',
  ),
  ModelQuestion(
    id: 'sec_math_03', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Statistics',
    question: 'Find the median of: 7, 3, 11, 5, 9, 2, 15, 6',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'Median = 6.5',
  ),
  ModelQuestion(
    id: 'sec_math_04', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Geometry',
    question: 'The lengths of two sides of a right triangle are 8 cm and 15 cm. Find the hypotenuse using Pythagoras\' theorem.',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'Hypotenuse = 17 cm',
  ),
  ModelQuestion(
    id: 'sec_math_05', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Number Theory',
    question: 'Find the HCF and LCM of 24, 36, and 48.',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'HCF = 12, LCM = 144',
  ),
  ModelQuestion(
    id: 'sec_math_06', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'math',
    chapter: 'Mensuration',
    question: 'Find the volume of a cylinder with radius 7 cm and height 10 cm. (Use π = 22/7)',
    type: QuestionType.shortAnswer, marks: 4,
    answer: 'Volume = 1,540 cm³',
  ),
];

const _sec89Science = [
  ModelQuestion(
    id: 'sec_sci_01', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'science',
    chapter: 'Force & Motion',
    question: 'State Newton\'s three laws of motion. Give one real-life example for each law.',
    type: QuestionType.longAnswer, marks: 6,
  ),
  ModelQuestion(
    id: 'sec_sci_02', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'science',
    chapter: 'Sound',
    question: 'The speed of sound in air is approximately:',
    type: QuestionType.mcq, marks: 1,
    options: ['343 m/s', '300 m/s', '3×10⁸ m/s', '1500 m/s'],
    answer: '343 m/s',
  ),
  ModelQuestion(
    id: 'sec_sci_03', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'science',
    chapter: 'Human Biology',
    question: 'Draw a labelled diagram of the human heart. Explain how blood circulates through the heart.',
    type: QuestionType.longAnswer, marks: 6,
  ),
  ModelQuestion(
    id: 'sec_sci_04', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'science',
    chapter: 'Chemistry',
    question: 'What is the difference between a physical change and a chemical change? Give two examples of each.',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'sec_sci_05', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'science',
    chapter: 'Environment',
    question: 'What is the greenhouse effect? Explain how it is leading to global warming and its impact on Nepal\'s glaciers.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
];

const _sec89Social = [
  ModelQuestion(
    id: 'sec_social_01', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'social',
    chapter: 'Nepal Geography',
    question: 'Name the major river systems of Nepal. Which river originates from the Himalayan range and which from the Mahabharat range?',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'sec_social_02', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'social',
    chapter: 'Democracy',
    question: 'What is democracy? Explain the importance of democracy with reference to Nepal\'s political history.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'sec_social_03', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'social',
    chapter: 'Disasters',
    question: 'Nepal is considered a high earthquake-risk country. Explain the causes of earthquakes in Nepal and the measures taken after the 2015 earthquake.',
    type: QuestionType.longAnswer, marks: 7,
  ),
];

const _sec89English = [
  ModelQuestion(
    id: 'sec_eng_01', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'english',
    chapter: 'Grammar - Tense',
    question: 'Fill in the blanks using the correct tense:\n(a) She ____ (go) to school every day.\n(b) They ____ (watch) a movie when I arrived.\n(c) I ____ (complete) my homework by 6 PM.',
    type: QuestionType.shortAnswer, marks: 3,
  ),
  ModelQuestion(
    id: 'sec_eng_02', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'english',
    chapter: 'Writing - Paragraph',
    question: 'Write a paragraph about "The Importance of Trees in Our Life" in about 100 words.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'sec_eng_03', gradeBandMin: 8, gradeBandMax: 9, subjectKey: 'english',
    chapter: 'Grammar - Conditional',
    question: 'Complete the sentences using conditional form:\n(a) If it rains, ____\n(b) If I were rich, ____\n(c) If she had studied hard, ____',
    type: QuestionType.shortAnswer, marks: 3,
  ),
];

// ─── MIDDLE — GRADES 6-7 ───────────────────────────────────────────────────

const _mid67Math = [
  ModelQuestion(
    id: 'mid_math_01', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'math',
    chapter: 'Fractions',
    question: 'Simplify: 3/4 + 5/6 - 1/3',
    type: QuestionType.shortAnswer, marks: 3,
    answer: '17/12 = 1 5/12',
  ),
  ModelQuestion(
    id: 'mid_math_02', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'math',
    chapter: 'Algebra',
    question: 'Solve for x: 3x + 7 = 22',
    type: QuestionType.shortAnswer, marks: 2,
    answer: 'x = 5',
  ),
  ModelQuestion(
    id: 'mid_math_03', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'math',
    chapter: 'Geometry',
    question: 'Find the area and perimeter of a rectangle with length 12 cm and width 8 cm.',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'Area = 96 cm², Perimeter = 40 cm',
  ),
  ModelQuestion(
    id: 'mid_math_04', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'math',
    chapter: 'Percentage',
    question: 'A student scored 72 marks out of 90. What is the percentage score? Is this above or below 75%?',
    type: QuestionType.shortAnswer, marks: 3,
    answer: '80% — above 75%',
  ),
  ModelQuestion(
    id: 'mid_math_05', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'math',
    chapter: 'Number Theory',
    question: 'Write all the prime numbers between 20 and 50.',
    type: QuestionType.shortAnswer, marks: 2,
    answer: '23, 29, 31, 37, 41, 43, 47',
  ),
];

const _mid67Science = [
  ModelQuestion(
    id: 'mid_sci_01', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'science',
    chapter: 'Living Things',
    question: 'What is the difference between a plant cell and an animal cell? Draw and label a plant cell.',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'mid_sci_02', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'science',
    chapter: 'Water',
    question: 'Explain the water cycle with a diagram. How does the water cycle affect Nepal\'s monsoon season?',
    type: QuestionType.longAnswer, marks: 6,
  ),
  ModelQuestion(
    id: 'mid_sci_03', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'science',
    chapter: 'Force',
    question: 'What is gravity? Why does an apple fall from a tree but the moon does not fall to the Earth?',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'mid_sci_04', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'science',
    chapter: 'Plants',
    question: 'Which part of the plant makes food?',
    type: QuestionType.mcq, marks: 1,
    options: ['Root', 'Stem', 'Leaf', 'Flower'],
    answer: 'Leaf (chlorophyll in leaves performs photosynthesis)',
  ),
];

const _mid67Social = [
  ModelQuestion(
    id: 'mid_social_01', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'social',
    chapter: 'Nepal Culture',
    question: 'Describe three major festivals of Nepal. When are they celebrated and what is their significance?',
    type: QuestionType.shortAnswer, marks: 5,
  ),
  ModelQuestion(
    id: 'mid_social_02', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'social',
    chapter: 'Nepal Geography',
    question: 'Name the five development regions of Nepal. Which development region has the highest population?',
    type: QuestionType.shortAnswer, marks: 4,
  ),
  ModelQuestion(
    id: 'mid_social_03', gradeBandMin: 6, gradeBandMax: 7, subjectKey: 'social',
    chapter: 'Natural Resources',
    question: 'What are natural resources? Give examples of renewable and non-renewable resources found in Nepal.',
    type: QuestionType.shortAnswer, marks: 4,
  ),
];

// ─── PRIMARY — GRADES 4-5 ─────────────────────────────────────────────────

const _pri45Math = [
  ModelQuestion(
    id: 'pri_math_01', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'math',
    chapter: 'Multiplication',
    question: 'Solve: 345 × 24 = ?',
    type: QuestionType.shortAnswer, marks: 2,
    answer: '8,280',
  ),
  ModelQuestion(
    id: 'pri_math_02', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'math',
    chapter: 'Fractions',
    question: 'Which fraction is larger: 3/4 or 5/8? Show your working.',
    type: QuestionType.shortAnswer, marks: 2,
    answer: '3/4 = 6/8, so 3/4 is larger',
  ),
  ModelQuestion(
    id: 'pri_math_03', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'math',
    chapter: 'Geometry',
    question: 'What is the area of a triangle with base 10 cm and height 6 cm?',
    type: QuestionType.shortAnswer, marks: 2,
    answer: 'Area = ½ × 10 × 6 = 30 cm²',
  ),
  ModelQuestion(
    id: 'pri_math_04', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'math',
    chapter: 'Measurement',
    question: 'Convert: 2.5 km = ____ m = ____ cm',
    type: QuestionType.shortAnswer, marks: 2,
    answer: '2,500 m = 250,000 cm',
  ),
];

const _pri45Science = [
  ModelQuestion(
    id: 'pri_sci_01', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'science',
    chapter: 'Plants',
    question: 'What do plants need to make their own food? Name the process.',
    type: QuestionType.shortAnswer, marks: 3,
    answer: 'Sunlight, water, CO₂, chlorophyll — Process: Photosynthesis',
  ),
  ModelQuestion(
    id: 'pri_sci_02', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'science',
    chapter: 'States of Matter',
    question: 'Name the three states of matter. Give one example of each that you find in Nepal.',
    type: QuestionType.shortAnswer, marks: 3,
  ),
  ModelQuestion(
    id: 'pri_sci_03', gradeBandMin: 4, gradeBandMax: 5, subjectKey: 'science',
    chapter: 'Animals',
    question: 'The national animal of Nepal is:',
    type: QuestionType.mcq, marks: 1,
    options: ['Tiger', 'Snow Leopard', 'Cow', 'Elephant'],
    answer: 'Cow (गाई — national animal of Nepal)',
  ),
];

// ─── ALL QUESTIONS MAP ─────────────────────────────────────────────────────

/// All questions in one flat list — use [questionsForGrade] to filter.
List<ModelQuestion> get allModelQuestions => [
  ..._seeMath, ..._seeScience, ..._seeSocial,
  ..._seeEnglish, ..._seeNepali, ..._seeOptMath,
  ..._sec89Math, ..._sec89Science, ..._sec89Social, ..._sec89English,
  ..._mid67Math, ..._mid67Science, ..._mid67Social,
  ..._pri45Math, ..._pri45Science,
];

/// Returns questions appropriate for the given grade, optionally filtered by subject key.
List<ModelQuestion> questionsForGrade(int grade, {String? subjectKey}) {
  return allModelQuestions.where((q) {
    final gradeOk = q.matchesGrade(grade);
    final subjectOk = subjectKey == null || q.matchesSubject(subjectKey);
    return gradeOk && subjectOk;
  }).toList();
}

/// Subject keys that have questions for a given grade.
List<String> subjectKeysWithQuestions(int grade) {
  return allModelQuestions
      .where((q) => q.matchesGrade(grade))
      .map((q) => q.subjectKey)
      .toSet()
      .toList();
}
