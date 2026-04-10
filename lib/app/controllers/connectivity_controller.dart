import 'dart:async';

import 'package:get/get.dart';

import '../../data/services/connectivity_mode_service.dart';

class ConnectivityController extends GetxController {
  ConnectivityController(this._service);

  final ConnectivityModeService _service;

  final mode = AppConnectivityMode.offline.obs;
  final isChecking = false.obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _refresh();
    _sub = _service.onConnectivityChanged.listen((_) => _refresh());
  }

  Future<void> manualRefresh() => _refresh();

  Future<void> _refresh() async {
    if (isChecking.value) return;
    isChecking.value = true;
    try {
      mode.value = await _service.detectMode();
    } finally {
      isChecking.value = false;
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

