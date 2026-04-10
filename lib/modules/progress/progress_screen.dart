import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../widgets/progress_ring.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(
            child: ProgressRing(progress: 0.42, size: 120),
          ),
          ListTile(
            title: const Text('By subject'),
            onTap: () => Get.toNamed(AppRoutes.subjectProgress),
          ),
        ],
      ),
    );
  }
}
