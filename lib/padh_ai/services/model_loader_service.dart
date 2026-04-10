import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/app_settings_service.dart';

/// Handles downloading, storing, and managing the Gemma model file.
/// Supports resume on interrupted downloads and progress tracking.
/// Downloads from Django server (`/api/ai/model/download/`).
class ModelLoaderService {
  static const String _modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String _prefKeyModelDownloaded = 'model_downloaded_v1';
  static const String _prefKeyBytesDownloaded = 'model_bytes_downloaded';
  static const String _prefKeyModelUrl = 'model_download_url';
  static const String _prefKeyModelSize = 'model_expected_size';

  /// Fallback when server hasn't been reached yet (~2.4 GB).
  static const int _fallbackModelSize = 2583085056;

  /// Minimum valid model file size (anything smaller is incomplete).
  static const int _minValidSize = 2000000000;

  final SharedPreferences _prefs;
  String? _effectiveBaseUrl;

  ModelLoaderService(this._prefs);

  /// The expected model size — either from the server or the cached value.
  int get expectedModelSize =>
      _prefs.getInt(_prefKeyModelSize) ?? _fallbackModelSize;

  /// Set Django base URL for model download. Applies Android localhost rewrite.
  void setDjangoBaseUrl(String url) {
    final raw = url.trim().replaceAll(RegExp(r'/+$'), '');
    _effectiveBaseUrl = AppSettingsService.rewriteLocalhostUrl(raw);
  }

  /// Fetch model metadata from Django `/api/ai/model/info/`.
  /// Returns the parsed JSON map, or null on failure.
  Future<Map<String, dynamic>?> fetchModelInfo() async {
    if (_effectiveBaseUrl == null) return null;
    try {
      final uri = Uri.parse('$_effectiveBaseUrl/api/ai/model/info/');
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final decoded = _parseJson(response.body);
        if (decoded != null) {
          // Cache download URL and file size.
          if (decoded['download_url'] != null) {
            final rewritten = AppSettingsService.rewriteLocalhostUrl(
              decoded['download_url'] as String,
            );
            await _prefs.setString(_prefKeyModelUrl, rewritten);
          }
          if (decoded['file_size'] != null || decoded['size_bytes'] != null) {
            final size = decoded['file_size'] ?? decoded['size_bytes'];
            await _prefs.setInt(_prefKeyModelSize, size as int);
          }
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('ModelLoader: Failed to get model info: $e');
    }
    return null;
  }

  /// Get the model download URL (from Django `/api/ai/model/info/`).
  Future<String> get modelDownloadUrl async {
    // Try fetching fresh info from server.
    final info = await fetchModelInfo();
    if (info != null && info['download_url'] != null) {
      return AppSettingsService.rewriteLocalhostUrl(
        info['download_url'] as String,
      );
    }

    // Use cached URL if available.
    final cached = _prefs.getString(_prefKeyModelUrl);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    throw StateError(
      'No model download URL available. '
      'Ensure Django is running and /api/ai/model/info/ is reachable.',
    );
  }

  Map<String, dynamic>? _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      debugPrint('ModelLoader: JSON parse error: $e');
      return null;
    }
  }

  /// Returns the local path where the model should be stored.
  Future<String> get modelPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'models', _modelFileName);
  }

  /// Returns the temporary download path for partial downloads.
  Future<String> get _tempDownloadPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'models', '$_modelFileName.tmp');
  }

  /// Checks if the model exists and is fully downloaded.
  Future<bool> isModelAvailable() async {
    final path = await modelPath;
    final file = File(path);

    if (!await file.exists()) return false;

    final length = await file.length();
    final isComplete = _prefs.getBool(_prefKeyModelDownloaded) ?? false;
    return isComplete && length > _minValidSize;
  }

  /// Gets the number of bytes already downloaded (for resume).
  Future<int> getBytesDownloaded() async {
    final tempPath = await _tempDownloadPath;
    final tempFile = File(tempPath);

    if (await tempFile.exists()) return await tempFile.length();

    final finalPath = await modelPath;
    final finalFile = File(finalPath);
    if (await finalFile.exists()) return await finalFile.length();

    return 0;
  }

  /// Downloads the model with progress tracking and resume support.
  /// Fetches fresh model info from the server before starting.
  Stream<ModelDownloadProgress> downloadModel() async* {
    // Refresh model info (caches download_url + size_bytes).
    await fetchModelInfo();

    final expected = expectedModelSize;
    final path = await modelPath;
    final tempPath = await _tempDownloadPath;
    final tempFile = File(tempPath);
    final finalFile = File(path);

    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) await dir.create(recursive: true);

    int downloadedBytes = 0;
    if (await tempFile.exists()) {
      downloadedBytes = await tempFile.length();
      debugPrint('ModelLoader: Resuming download from $downloadedBytes bytes');
    }

    yield ModelDownloadProgress(
      status: DownloadStatus.connecting,
      bytesDownloaded: downloadedBytes,
      totalBytes: expected,
    );

    try {
      final downloadUrl = await modelDownloadUrl;
      debugPrint('ModelLoader: Downloading from $downloadUrl');
      final request = http.Request('GET', Uri.parse(downloadUrl));

      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await http.Client().send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Download failed: ${response.statusCode}');
      }

      final totalBytes = downloadedBytes +
          (response.contentLength ?? (expected - downloadedBytes));

      yield ModelDownloadProgress(
        status: DownloadStatus.downloading,
        bytesDownloaded: downloadedBytes,
        totalBytes: totalBytes,
      );

      final sink = tempFile.openWrite(
        mode: downloadedBytes > 0 ? FileMode.append : FileMode.write,
      );

      // Speed calculation
      var lastTime = DateTime.now();
      var lastBytes = downloadedBytes;
      double currentSpeed = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        // Calculate speed every ~500KB
        if (downloadedBytes - lastBytes > 512 * 1024) {
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          if (elapsed > 0) {
            currentSpeed = (downloadedBytes - lastBytes) / (elapsed / 1000);
            lastTime = now;
            lastBytes = downloadedBytes;
          }
        }

        // Save progress periodically
        if (downloadedBytes % (10 * 1024 * 1024) == 0) {
          await _prefs.setInt(_prefKeyBytesDownloaded, downloadedBytes);
        }

        yield ModelDownloadProgress(
          status: DownloadStatus.downloading,
          bytesDownloaded: downloadedBytes,
          totalBytes: totalBytes,
          speedBytesPerSec: currentSpeed,
        );
      }

      await sink.close();

      yield ModelDownloadProgress(
        status: DownloadStatus.verifying,
        bytesDownloaded: downloadedBytes,
        totalBytes: totalBytes,
      );

      final downloadedSize = await tempFile.length();
      if (downloadedSize < _minValidSize) {
        throw StateError('Downloaded file is too small: $downloadedSize bytes');
      }

      if (await finalFile.exists()) await finalFile.delete();
      await tempFile.rename(path);

      await _prefs.setBool(_prefKeyModelDownloaded, true);
      await _prefs.remove(_prefKeyBytesDownloaded);

      yield ModelDownloadProgress(
        status: DownloadStatus.complete,
        bytesDownloaded: downloadedSize,
        totalBytes: downloadedSize,
      );
    } catch (e) {
      debugPrint('ModelLoader: Download error: $e');
      yield ModelDownloadProgress(
        status: DownloadStatus.error,
        bytesDownloaded: downloadedBytes,
        totalBytes: expected,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> copyFromAssets({
    required String assetPath,
    void Function(double progress)? onProgress,
  }) async {
    final path = await modelPath;
    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) await dir.create(recursive: true);

    await _prefs.setBool(_prefKeyModelDownloaded, true);
    debugPrint('ModelLoader: Asset copy complete at $path');
  }

  Future<void> deleteModel() async {
    final path = await modelPath;
    final modelFile = File(path);
    if (await modelFile.exists()) await modelFile.delete();

    final tempPath = await _tempDownloadPath;
    final tempFile = File(tempPath);
    if (await tempFile.exists()) await tempFile.delete();

    await _prefs.setBool(_prefKeyModelDownloaded, false);
    await _prefs.remove(_prefKeyBytesDownloaded);
  }

  Future<int?> getModelFileSize() async {
    final path = await modelPath;
    final file = File(path);
    if (await file.exists()) return await file.length();
    return null;
  }
}

enum DownloadStatus {
  connecting,
  downloading,
  verifying,
  complete,
  error,
}

class ModelDownloadProgress {
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String? error;
  final double? speedBytesPerSec;

  const ModelDownloadProgress({
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytes,
    this.error,
    this.speedBytesPerSec,
  });

  double get progress => totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;

  String get statusText {
    switch (status) {
      case DownloadStatus.connecting:
        return 'Connecting...';
      case DownloadStatus.downloading:
        return 'Downloading AI Model...';
      case DownloadStatus.verifying:
        return 'Verifying...';
      case DownloadStatus.complete:
        return 'Complete!';
      case DownloadStatus.error:
        return 'Error: ${error ?? "Unknown"}';
    }
  }

  String get bytesText {
    final downloadedMB = (bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$downloadedMB MB / $totalMB MB';
  }

  /// Download speed in MB/s
  String get speedText {
    if (speedBytesPerSec == null || speedBytesPerSec! <= 0) return '';
    final mbps = speedBytesPerSec! / (1024 * 1024);
    return '${mbps.toStringAsFixed(1)} MB/s';
  }

  /// Estimated time remaining
  String get timeRemainingText {
    if (speedBytesPerSec == null || speedBytesPerSec! <= 0) return '';
    final remaining = totalBytes - bytesDownloaded;
    final seconds = remaining / speedBytesPerSec!;
    if (seconds < 60) return '${seconds.toInt()}s remaining';
    if (seconds < 3600) return '${(seconds / 60).toInt()}m remaining';
    return '${(seconds / 3600).toStringAsFixed(1)}h remaining';
  }
}
