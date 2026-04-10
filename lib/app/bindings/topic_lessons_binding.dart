import 'package:get/get.dart';

import '../../modules/subjects/topic_lessons_controller.dart';

class TopicLessonsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TopicLessonsController>(() => TopicLessonsController());
  }
}
