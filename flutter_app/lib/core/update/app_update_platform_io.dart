import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _updaterChannel =
    MethodChannel('com.ots120.flutter_app/updater');

const Duration _networkTimeout = Duration(seconds: 10);

/// Returns the installed Android `versionCode` via native [MethodChannel].
Future<int> getLocalVersionCodePlatform() async {
  if (kIsWeb || !Platform.isAndroid) return 0;
  final result = await _updaterChannel.invokeMethod<int>('getVersionCode');
  return result ?? 0;
}

/// Fetches and decodes `version.json` from [url] with a bounded timeout.
Future<Map<String, dynamic>?> fetchRemoteReleaseJsonPlatform(String url) async {
  if (kIsWeb || !Platform.isAndroid) return null;
  final client = HttpClient()..connectionTimeout = _networkTimeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(_networkTimeout);
    final response = await request.close().timeout(_networkTimeout);
    if (response.statusCode != HttpStatus.ok) return null;
    final body =
        await response.transform(utf8.decoder).join().timeout(_networkTimeout);
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Downloads the APK from [url] into the app's cache `updates/` directory.
Future<String> downloadApkPlatform(
  String url,
  void Function(double progress) onProgress,
) async {
  if (kIsWeb || !Platform.isAndroid) {
    throw UnsupportedError('APK self-update is only supported on Android.');
  }
  final cacheDir = await _updaterChannel.invokeMethod<String>('getCacheDir');
  if (cacheDir == null || cacheDir.isEmpty) {
    throw StateError('Unable to resolve Android cache directory.');
  }

  final updatesDir = Directory('$cacheDir/updates');
  if (!updatesDir.existsSync()) {
    updatesDir.createSync(recursive: true);
  }
  final targetFile = File('${updatesDir.path}/ots-contador-release.apk');
  if (targetFile.existsSync()) {
    targetFile.deleteSync();
  }

  final client = HttpClient()..connectionTimeout = _networkTimeout;
  IOSink? sink;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(_networkTimeout);
    final response = await request.close().timeout(const Duration(minutes: 2));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Unexpected HTTP ${response.statusCode} downloading APK.',
        uri: Uri.parse(url),
      );
    }

    final totalBytes = response.contentLength;
    var receivedBytes = 0;
    sink = targetFile.openWrite();

    await for (final chunk in response) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
      }
    }
    await sink.flush();
    onProgress(1.0);
    return targetFile.path;
  } finally {
    await sink?.close();
    client.close(force: true);
  }
}

/// Launches the Android package installer for the APK at [filePath].
Future<String> installApkPlatform(String filePath) async {
  if (kIsWeb || !Platform.isAndroid) {
    throw UnsupportedError('APK self-update is only supported on Android.');
  }
  final result = await _updaterChannel.invokeMethod<String>(
    'installApk',
    {'path': filePath},
  );
  return result ?? 'error';
}
