import 'package:get/get.dart';

import '../../modules/subjects/subjects_controller.dart';

class SubjectsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubjectsController>(() => SubjectsController());
  }
}
