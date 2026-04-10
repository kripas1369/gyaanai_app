import 'package:get/get.dart';

import '../../data/services/local_db_service.dart';
import '../../data/services/sync_service.dart';

class SubjectsController extends GetxController {
  final items = <Map<String, dynamic>>[].obs;
  final loading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final local = Get.find<LocalDbService>();
      var list = await local.getAllSubjects();
      if (list.isEmpty) {
        await Get.find<SyncService>().syncCurriculum();
        list = await local.getAllSubjects();
      }
      items.assignAll(list);
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
