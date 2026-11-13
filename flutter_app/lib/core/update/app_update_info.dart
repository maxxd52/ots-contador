/// Metadata for an available Android APK release hosted on GitHub Releases.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;

  static const String _trustedReleasePrefix =
      'https://github.com/maxxd52/ots-contador/releases/';

  /// Parses [json] and validates required fields and trusted download origin.
  /// Returns `null` when malformed or untrusted.
  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    final rawName = json['versionName'];
    final rawCode = json['versionCode'];
    final rawUrl = json['apkUrl'];

    if (rawName is! String || rawName.trim().isEmpty) return null;
    if (rawCode is! int || rawCode <= 0) return null;
    if (rawUrl is! String || !rawUrl.startsWith(_trustedReleasePrefix)) {
      return null;
    }

    return AppUpdateInfo(
      versionName: rawName.trim(),
      versionCode: rawCode,
      apkUrl: rawUrl.trim(),
    );
  }

  /// Returns `true` when this release is newer than [currentVersionCode].
  bool isNewerThan(int currentVersionCode) => versionCode > currentVersionCode;
}
