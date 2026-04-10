import 'package:get/get.dart';

import '../../data/services/api_service.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/connectivity_mode_service.dart';
import '../../data/services/local_db_service.dart';
import '../../data/services/sync_service.dart';
import '../controllers/connectivity_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // AppSettingsService + LocalDbService are registered in main().

    Get.lazyPut<ApiService>(
      () => ApiService(Get.find<AppSettingsService>()),
      fenix: true,
    );

    Get.lazyPut<ConnectivityModeService>(
      () => ConnectivityModeService(Get.find<AppSettingsService>()),
      fenix: true,
    );

    Get.lazyPut<SyncService>(
      () => SyncService(
        Get.find<AppSettingsService>(),
        Get.find<ApiService>(),
        Get.find<LocalDbService>(),
        Get.find<ConnectivityModeService>(),
      ),
      fenix: true,
    );

    Get.put<ConnectivityController>(
      ConnectivityController(Get.find<ConnectivityModeService>()),
      permanent: true,
    );
  }
}

