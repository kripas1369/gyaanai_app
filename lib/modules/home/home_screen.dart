import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../widgets/offline_banner.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.title.value))),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OfflineBanner(offline: false),
          Expanded(
            child: Center(
              child: Text('Dashboard — hook navigation here'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              Get.toNamed(AppRoutes.subjects);
            case 1:
              Get.toNamed(AppRoutes.chat);
            case 2:
              Get.toNamed(AppRoutes.settings);
          }
        },
      ),
    );
  }
}
