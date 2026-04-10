import 'package:get/get.dart';

import '../../data/services/local_db_service.dart';
import '../../data/services/sync_service.dart';

class TopicsController extends GetxController {
  late final int subjectId;
  late final String subjectName;

  final topics = <Map<String, dynamic>>[].obs;
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    subjectId = args?['subjectId'] as int? ?? 0;
    subjectName = args?['subjectName'] as String? ?? 'Topics';
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final local = Get.find<LocalDbService>();
      var list = await local.getTopicsForSubject(subjectId);
      if (list.isEmpty) {
        await Get.find<SyncService>().syncCurriculum();
        list = await local.getTopicsForSubject(subjectId);
      }
      topics.assignAll(list);
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
