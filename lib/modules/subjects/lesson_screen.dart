import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import 'lesson_controller.dart';

class LessonScreen extends GetView<LessonController> {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = (Get.arguments as Map<String, dynamic>?)?['title'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Lesson')),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error.value != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(controller.error.value!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final d = controller.detail.value;
        if (d == null) {
          return const Center(child: Text('No data'));
        }
        final lang = Localizations.localeOf(context).languageCode;
        final body = lang == 'ne'
            ? (d['content_ne'] as String? ?? '')
            : (d['content_en'] as String? ?? d['content_ne'] as String? ?? '');
        return Markdown(
          padding: const EdgeInsets.all(16),
          data: body.isEmpty ? '(No content)' : body,
        );
      }),
    );
  }
}
