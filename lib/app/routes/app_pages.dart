import 'package:get/get.dart';

import '../bindings/auth_binding.dart';
import '../bindings/chat_binding.dart';
import '../bindings/home_binding.dart';
import '../bindings/lesson_binding.dart';
import '../bindings/quiz_binding.dart';
import '../bindings/subjects_binding.dart';
import '../bindings/topic_lessons_binding.dart';
import '../bindings/topics_binding.dart';
import 'app_routes.dart';
import '../../modules/auth/login_screen.dart';
import '../../modules/auth/register_screen.dart';
import '../../modules/chat/chat_screen.dart';
import '../../modules/home/home_screen.dart';
import '../../modules/progress/progress_screen.dart';
import '../../modules/progress/subject_progress_screen.dart';
import '../../modules/quiz/quiz_result_screen.dart';
import '../../modules/quiz/quiz_screen.dart';
import '../../modules/settings/ollama_config_screen.dart';
import '../../modules/settings/settings_screen.dart';
import '../../modules/subjects/lesson_screen.dart';
import '../../modules/subjects/subjects_screen.dart';
import '../../modules/subjects/topic_lessons_screen.dart';
import '../../modules/subjects/topics_screen.dart';
import '../../modules/teacher/student_detail_screen.dart';
import '../../modules/teacher/teacher_dashboard.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.home;

  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: HomeScreen.new,
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: LoginScreen.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: RegisterScreen.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.subjects,
      page: SubjectsScreen.new,
      binding: SubjectsBinding(),
    ),
    GetPage(
      name: AppRoutes.topics,
      page: TopicsScreen.new,
      binding: TopicsBinding(),
    ),
    GetPage(
      name: AppRoutes.topicLessons,
      page: TopicLessonsScreen.new,
      binding: TopicLessonsBinding(),
    ),
    GetPage(
      name: AppRoutes.lesson,
      page: LessonScreen.new,
      binding: LessonBinding(),
    ),
    GetPage(
      name: AppRoutes.chat,
      page: ChatScreen.new,
      binding: ChatBinding(),
    ),
    GetPage(
      name: AppRoutes.quiz,
      page: QuizScreen.new,
      binding: QuizBinding(),
    ),
    GetPage(
      name: AppRoutes.quizResult,
      page: QuizResultScreen.new,
      binding: QuizBinding(),
    ),
    GetPage(
      name: AppRoutes.progress,
      page: ProgressScreen.new,
    ),
    GetPage(
      name: AppRoutes.subjectProgress,
      page: SubjectProgressScreen.new,
    ),
    GetPage(
      name: AppRoutes.settings,
      page: SettingsScreen.new,
    ),
    GetPage(
      name: AppRoutes.ollamaConfig,
      page: OllamaConfigScreen.new,
    ),
    GetPage(
      name: AppRoutes.teacherDashboard,
      page: TeacherDashboard.new,
    ),
    GetPage(
      name: AppRoutes.studentDetail,
      page: StudentDetailScreen.new,
    ),
  ];
}
