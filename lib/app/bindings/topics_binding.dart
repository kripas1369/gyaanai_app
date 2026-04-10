import 'package:get/get.dart';

import '../../modules/subjects/topics_controller.dart';

class TopicsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TopicsController>(() => TopicsController());
  }
}
