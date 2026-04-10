import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../widgets/loading_shimmer.dart';
import 'topic_lessons_controller.dart';

class TopicLessonsScreen extends GetView<TopicLessonsController> {
  const TopicLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.topicTitle)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: controller.syncNow,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.lessons.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(height: 72),
          );
        }
        if (controller.error.value != null && controller.lessons.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(controller.error.value!, textAlign: TextAlign.center),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.syncNow,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: controller.lessons.length,
            itemBuilder: (context, i) {
              final l = controller.lessons[i];
              final title = (l['title_ne'] as String?)?.trim().isNotEmpty == true
                  ? l['title_ne'] as String
                  : (l['title_en'] as String? ?? 'Lesson');
              final lid = l['id'] as int;
              return ListTile(
                title: Text(title),
                subtitle: Text('${l['lesson_type']} · ${l['estimated_minutes']} min'),
                onTap: () => Get.toNamed(
                  AppRoutes.lesson,
                  arguments: {'lessonId': lid, 'title': title},
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
