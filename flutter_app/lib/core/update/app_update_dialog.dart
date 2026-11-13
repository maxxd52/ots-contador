import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_update_info.dart';
import 'app_update_service.dart';

/// Prompts the user to download and install a newer Android APK release.
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.service,
  });

  final AppUpdateInfo info;
  final AppUpdateService service;

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo info,
    required AppUpdateService service,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(info: info, service: service),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _statusMessage;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _statusMessage = 'Descargando actualización...';
    });

    try {
      final result = await widget.service.downloadAndInstall(
        widget.info,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
          });
        },
      );

      if (!mounted) return;
      if (result == ApkInstallResult.needsPermission) {
        setState(() {
          _isDownloading = false;
          _statusMessage =
              'Habilitá "Instalar apps desconocidas" y volvé a tocar Actualizar.';
        });
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = null;
        _errorMessage = 'No se pudo descargar la actualización. Intentá más tarde.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.system_update, color: AppColors.primaryPurple),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nueva versión disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versión ${widget.info.versionName} (build ${widget.info.versionCode}) lista para instalar.',
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (_statusMessage != null && !_isDownloading) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: const TextStyle(fontSize: 13, color: AppColors.warningAmberDark),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 13, color: Colors.redAccent),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: _isDownloading ? null : _startUpdate,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryPurple),
          child: const Text('Actualizar'),
        ),
      ],
    );
  }
}
