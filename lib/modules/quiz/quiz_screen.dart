import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import 'quiz_controller.dart';

class QuizScreen extends GetView<QuizController> {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: Center(
        child: FilledButton(
          onPressed: () => Get.toNamed(AppRoutes.quizResult),
          child: const Text('Finish (stub)'),
        ),
      ),
    );
  }
}
