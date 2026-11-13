/// Stub platform implementation for non-Android / Web targets.
Future<int> getLocalVersionCodePlatform() async => 0;

Future<Map<String, dynamic>?> fetchRemoteReleaseJsonPlatform(String url) async =>
    null;

Future<String> downloadApkPlatform(
  String url,
  void Function(double progress) onProgress,
) async {
  throw UnsupportedError('APK self-update is only supported on Android.');
}

Future<String> installApkPlatform(String filePath) async {
  throw UnsupportedError('APK self-update is only supported on Android.');
}
