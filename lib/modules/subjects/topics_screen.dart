import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../widgets/loading_shimmer.dart';
import 'topics_controller.dart';

class TopicsScreen extends GetView<TopicsController> {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.subjectName)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: controller.syncNow,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.topics.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingShimmer(height: 72),
          );
        }
        if (controller.error.value != null && controller.topics.isEmpty) {
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
            itemCount: controller.topics.length,
            itemBuilder: (context, i) {
              final t = controller.topics[i];
              final title = (t['name_ne'] as String?)?.trim().isNotEmpty == true
                  ? t['name_ne'] as String
                  : (t['name_en'] as String? ?? 'Topic');
              final tid = t['id'] as int;
              return ListTile(
                title: Text(title),
                subtitle: Text('Grade ${t['grade']}'),
                onTap: () => Get.toNamed(
                  AppRoutes.topicLessons,
                  arguments: {'topicId': tid, 'topicTitle': title},
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
