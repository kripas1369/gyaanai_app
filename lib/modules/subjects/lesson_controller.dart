import 'package:get/get.dart';

import '../../data/services/sync_service.dart';

class LessonController extends GetxController {
  final detail = Rxn<Map<String, dynamic>>();
  final loading = true.obs;
  final error = RxnString();

  late final int lessonId;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    lessonId = args?['lessonId'] as int? ?? 0;
    _load();
  }

  Future<void> _load() async {
    loading.value = true;
    error.value = null;
    try {
      final sync = Get.find<SyncService>();
      detail.value = await sync.ensureLessonDetail(lessonId);
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> retry() => _load();
}
