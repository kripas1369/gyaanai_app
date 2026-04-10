import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'quiz_controller.dart';

class QuizResultScreen extends GetView<QuizController> {
  const QuizResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Center(
        child: Obx(() => Text('Score: ${controller.score.value}')),
      ),
    );
  }
}
