import 'package:get/get.dart';

import '../../data/services/local_db_service.dart';
import '../../data/services/sync_service.dart';

class TopicLessonsController extends GetxController {
  late final int topicId;
  late final String topicTitle;

  final lessons = <Map<String, dynamic>>[].obs;
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    topicId = args?['topicId'] as int? ?? 0;
    topicTitle = args?['topicTitle'] as String? ?? 'Lessons';
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final local = Get.find<LocalDbService>();
      var list = await local.getLessonsForTopic(topicId);
      if (list.isEmpty) {
        await Get.find<SyncService>().syncCurriculum();
        list = await local.getLessonsForTopic(topicId);
      }
      lessons.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> syncNow() async {
    await Get.find<SyncService>().syncCurriculum();
    await load();
  }
}
