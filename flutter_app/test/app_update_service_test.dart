import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/update/app_update_info.dart';
import 'package:flutter_app/core/update/app_update_service.dart';

void main() {
  group('AppUpdateInfo', () {
    test('parses valid GitHub Release version.json', () {
      final info = AppUpdateInfo.fromJson({
        'versionName': '1.0.0',
        'versionCode': 15,
        'apkUrl':
            'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
      });

      expect(info, isNotNull);
      expect(info!.versionName, '1.0.0');
      expect(info.versionCode, 15);
      expect(info.isNewerThan(14), isTrue);
      expect(info.isNewerThan(15), isFalse);
      expect(info.isNewerThan(16), isFalse);
    });

    test('rejects untrusted apkUrl or invalid versionCode', () {
      expect(
        AppUpdateInfo.fromJson({
          'versionName': '1.0.0',
          'versionCode': 15,
          'apkUrl': 'https://evil.example.com/app.apk',
        }),
        isNull,
      );

      expect(
        AppUpdateInfo.fromJson({
          'versionName': '1.0.0',
          'versionCode': 0,
          'apkUrl':
              'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
        }),
        isNull,
      );

      expect(
        AppUpdateInfo.fromJson({
          'versionName': '',
          'versionCode': 5,
          'apkUrl':
              'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
        }),
        isNull,
      );
    });
  });

  group('AppUpdateService', () {
    test('returns update info only when remote versionCode is strictly greater', () async {
      final serviceNewer = AppUpdateService(
        getLocalVersionCode: () async => 10,
        fetchRemoteJson: () async => {
          'versionName': '1.0.0',
          'versionCode': 11,
          'apkUrl':
              'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
        },
        downloadFile: (_, _) async => '/tmp/app.apk',
        installApk: (_) async => ApkInstallResult.launched,
      );

      final result = await serviceNewer.checkForUpdate();
      expect(result, isNotNull);
      expect(result!.versionCode, 11);

      final serviceSame = AppUpdateService(
        getLocalVersionCode: () async => 11,
        fetchRemoteJson: () async => {
          'versionName': '1.0.0',
          'versionCode': 11,
          'apkUrl':
              'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
        },
        downloadFile: (_, _) async => '/tmp/app.apk',
        installApk: (_) async => ApkInstallResult.launched,
      );

      expect(await serviceSame.checkForUpdate(), isNull);
    });

    test('returns null silently when network or version check fails', () async {
      final service = AppUpdateService(
        getLocalVersionCode: () async => 10,
        fetchRemoteJson: () async => throw Exception('offline'),
        downloadFile: (_, _) async => '/tmp/app.apk',
        installApk: (_) async => ApkInstallResult.launched,
      );

      expect(await service.checkForUpdate(), isNull);
    });

    test('downloadAndInstall reports progress and invokes installer', () async {
      final progressEvents = <double>[];
      String? installedPath;

      final service = AppUpdateService(
        getLocalVersionCode: () async => 10,
        fetchRemoteJson: () async => null,
        downloadFile: (url, onProgress) async {
          onProgress(0.25);
          onProgress(1.0);
          return '/cache/updates/ots-contador-release.apk';
        },
        installApk: (path) async {
          installedPath = path;
          return ApkInstallResult.launched;
        },
      );

      final info = AppUpdateInfo.fromJson({
        'versionName': '1.0.0',
        'versionCode': 11,
        'apkUrl':
            'https://github.com/maxxd52/ots-contador/releases/latest/download/ots-contador-release.apk',
      })!;

      final status = await service.downloadAndInstall(
        info,
        onProgress: progressEvents.add,
      );

      expect(progressEvents, [0.25, 1.0]);
      expect(installedPath, '/cache/updates/ots-contador-release.apk');
      expect(status, ApkInstallResult.launched);
    });
  });
}
