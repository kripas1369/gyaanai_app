import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import 'auth_controller.dart';

class RegisterScreen extends GetView<AuthController> {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: FilledButton(
          onPressed: () => Get.offAllNamed(AppRoutes.home),
          child: const Text('Done (stub)'),
        ),
      ),
    );
  }
}
