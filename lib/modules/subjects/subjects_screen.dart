import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/subject_card.dart';
import 'subjects_controller.dart';

class SubjectsScreen extends GetView<SubjectsController> {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: controller.syncNow,
            tooltip: 'Sync from server',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              LoadingShimmer(height: 100),
              SizedBox(height: 12),
              LoadingShimmer(height: 100),
            ],
          );
        }
        if (controller.error.value != null && controller.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    controller.error.value!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.syncNow,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.syncNow,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: controller.items.length,
            itemBuilder: (context, i) {
              final s = controller.items[i];
              final id = s['id'] as int;
              final title = (s['name_ne'] as String?)?.trim().isNotEmpty == true
                  ? s['name_ne'] as String
                  : (s['name_en'] as String? ?? 'Subject');
              return SubjectCard(
                title: title,
                onTap: () => Get.toNamed(
                  AppRoutes.topics,
                  arguments: {
                    'subjectId': id,
                    'subjectName': title,
                  },
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
