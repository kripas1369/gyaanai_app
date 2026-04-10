import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Student'),
            onTap: () => Get.toNamed(AppRoutes.studentDetail),
          ),
        ],
      ),
    );
  }
}
