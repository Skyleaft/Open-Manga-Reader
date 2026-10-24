import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateData;
  final UpdateService updateService;

  const AppUpdateDialog({
    super.key,
    required this.updateData,
    required this.updateService,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> updateData, {
    UpdateService? updateService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppUpdateDialog(
        updateData: updateData,
        updateService: updateService ?? UpdateService(),
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;
  CancelToken? _cancelToken;

  String get _latestVersion => (widget.updateData['latestVersion'] ?? widget.updateData['version'] ?? '').toString();
  String get _currentVersion => (widget.updateData['currentVersion'] ?? '').toString();
  String get _body => (widget.updateData['body'] ?? 'Performance improvements and bug fixes.').toString();
  String? get _downloadUrl => widget.updateData['downloadUrl'] as String?;
  String get _fileName => (widget.updateData['fileName'] as String?) ?? 'update.apk';
  int get _fileSize => (widget.updateData['fileSize'] as num?)?.toInt() ?? 0;
  String get _targetAbi => (widget.updateData['targetAbi'] as String?) ?? '';

  Future<void> _startDownloadAndInstall() async {
    // If not on Android or no direct APK asset found, open external browser
    if (kIsWeb || !Platform.isAndroid || _downloadUrl == null) {
      final url = Uri.parse(widget.updateData['url'] ?? '');
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusText = 'Preparing download...';
      _cancelToken = CancelToken();
    });

    final filePath = await widget.updateService.downloadUpdate(
      downloadUrl: _downloadUrl!,
      fileName: _fileName,
      cancelToken: _cancelToken,
      onProgress: (progress, received, total) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          final currentStr = UpdateService.formatBytes(received);
          final totalStr = UpdateService.formatBytes(total);
          _statusText = '$currentStr / $totalStr (${(progress * 100).toInt()}%)';
        });
      },
    );

    if (!mounted) return;

    if (filePath != null) {
      setState(() {
        _statusText = 'Opening installer...';
      });
      final success = await widget.updateService.installApk(filePath);
      if (mounted && success) {
        Navigator.pop(context);
      } else if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Installation was not started. Please check permissions.';
        });
      }
    } else {
      if (_cancelToken?.isCancelled != true) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed. Check your internet connection.';
        });
      }
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel('User cancelled download');
    setState(() {
      _isDownloading = false;
      _progress = 0.0;
      _statusText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Icon & Title
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary,
                        primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'A newer version is ready to install',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.slate300 : AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Version & ABI Badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: Row(
                children: [
                  // Old Version
                  Text(
                    'v$_currentVersion',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.slate500 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isDark ? AppColors.slate500 : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  // New Version Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'v$_latestVersion',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Target ABI / Size Badge
                  if (_targetAbi.isNotEmpty || _fileSize > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_targetAbi.isNotEmpty) ...[
                            Icon(Icons.memory_rounded, size: 12, color: primary),
                            const SizedBox(width: 4),
                            Text(
                              _targetAbi,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                          if (_targetAbi.isNotEmpty && _fileSize > 0)
                            const Text(' • ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          if (_fileSize > 0)
                            Text(
                              UpdateService.formatBytes(_fileSize),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Changelog Title
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                const Text(
                  "What's New:",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Changelog Box
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate800.withValues(alpha: 0.5) : AppColors.slate100.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.slate700 : AppColors.slate200,
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: Text(
                    _body.trim().isEmpty ? 'Bug fixes and performance improvements.' : _body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: isDark ? AppColors.slate300 : AppColors.slate700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Progress Indicator during download
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.slate300 : AppColors.slate700,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 8,
                      backgroundColor: isDark ? AppColors.slate700 : AppColors.slate200,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _cancelDownload,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancel Download'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Action Buttons
              Row(
                children: [
                  // Dismiss button
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          color: isDark ? AppColors.slate500 : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Install / Update Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _startDownloadAndInstall,
                      icon: Icon(
                        Platform.isAndroid && _downloadUrl != null
                            ? Icons.download_rounded
                            : Icons.open_in_browser_rounded,
                        size: 18,
                      ),
                      label: Text(
                        Platform.isAndroid && _downloadUrl != null
                            ? 'Update Now'
                            : 'Open Browser',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 4,
                        shadowColor: primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
