import 'app_update_info.dart';
import 'app_update_platform_stub.dart'
    if (dart.library.io) 'app_update_platform_io.dart';

/// Outcome of invoking the Android APK installer.
enum ApkInstallResult {
  launched,
  needsPermission,
}

/// Checks GitHub Releases for newer Android APK builds and orchestrates download/install.
class AppUpdateService {
  AppUpdateService({
    Future<int> Function()? getLocalVersionCode,
    Future<Map<String, dynamic>?> Function()? fetchRemoteJson,
    Future<String> Function(String url, void Function(double) onProgress)?
        downloadFile,
    Future<ApkInstallResult> Function(String path)? installApk,
  })  : _getLocalVersionCode =
            getLocalVersionCode ?? getLocalVersionCodePlatform,
        _fetchRemoteJson = fetchRemoteJson ??
            (() => fetchRemoteReleaseJsonPlatform(defaultVersionJsonUrl)),
        _downloadFile = downloadFile ?? downloadApkPlatform,
        _installApk = installApk ?? _defaultInstallApk;

  static const String defaultVersionJsonUrl =
      'https://github.com/maxxd52/ots-contador/releases/latest/download/version.json';

  final Future<int> Function() _getLocalVersionCode;
  final Future<Map<String, dynamic>?> Function() _fetchRemoteJson;
  final Future<String> Function(String url, void Function(double) onProgress)
      _downloadFile;
  final Future<ApkInstallResult> Function(String path) _installApk;

  static Future<ApkInstallResult> _defaultInstallApk(String path) async {
    final status = await installApkPlatform(path);
    return status == 'needs_permission'
        ? ApkInstallResult.needsPermission
        : ApkInstallResult.launched;
  }

  /// Checks for an available update. Never throws; returns `null` when up-to-date
  /// or when offline/unavailable.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final localCode = await _getLocalVersionCode();
      if (localCode <= 0) return null;

      final json = await _fetchRemoteJson();
      if (json == null) return null;

      final info = AppUpdateInfo.fromJson(json);
      if (info == null || !info.isNewerThan(localCode)) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK described by [info] and triggers Android's installer.
  Future<ApkInstallResult> downloadAndInstall(
    AppUpdateInfo info, {
    required void Function(double progress) onProgress,
  }) async {
    final filePath = await _downloadFile(info.apkUrl, onProgress);
    return _installApk(filePath);
  }
}
