import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'app_settings_service.dart';

enum AppConnectivityMode { online, localNetwork, offline }

class ConnectivityModeService {
  ConnectivityModeService(this._settings);

  final AppSettingsService _settings;
  final _connectivity = Connectivity();

  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((e) => e.first);

  Future<AppConnectivityMode> detectMode() async {
    final connectivity = (await _connectivity.checkConnectivity()).first;
    final hasAnyNetwork = connectivity != ConnectivityResult.none;

    final ollamaOk = await _canReachHttp(
      _hostToUri(_settings.ollamaHost),
      timeout: const Duration(milliseconds: 800),
    );

    if (!hasAnyNetwork) {
      return ollamaOk ? AppConnectivityMode.localNetwork : AppConnectivityMode.offline;
    }

    final djangoOk = await _canReachDjangoHealth(
      timeout: const Duration(milliseconds: 1600),
    );
    if (djangoOk) return AppConnectivityMode.online;

    return ollamaOk ? AppConnectivityMode.localNetwork : AppConnectivityMode.offline;
  }

  Uri _hostToUri(String host) {
    final trimmed = host.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.parse(trimmed);
    }
    return Uri.parse('http://$trimmed');
  }

  Future<bool> _canReachHttp(Uri uri, {required Duration timeout}) async {
    try {
      final resp = await http
          .get(Uri(scheme: uri.scheme, host: uri.host, port: uri.port))
          .timeout(timeout, onTimeout: () => http.Response('timeout', 408));
      return resp.statusCode >= 200 && resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canReachDjangoHealth({required Duration timeout}) async {
    try {
      final base = _settings.effectiveDjangoBaseUrl;
      final uri = Uri.parse('$base/api/health/');
      final resp = await http.get(uri).timeout(
        timeout,
        onTimeout: () => http.Response('timeout', 408),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
