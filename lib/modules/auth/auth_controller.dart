import 'package:get/get.dart';

class AuthController extends GetxController {
  final isLoading = false.obs;

  void setLoading(bool v) => isLoading.value = v;
}
