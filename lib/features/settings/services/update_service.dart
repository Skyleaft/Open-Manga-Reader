import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  final Dio _dio = Dio();

  /// Mendeteksi ABI perangkat Android saat ini (e.g. arm64-v8a, armeabi-v7a, x86_64)
  String getAndroidAbi() {
    if (kIsWeb || !Platform.isAndroid) return '';
    try {
      final abiStr = Abi.current().toString().toLowerCase();
      if (abiStr.contains('arm64')) return 'arm64-v8a';
      if (abiStr.contains('arm')) return 'armeabi-v7a';
      if (abiStr.contains('x64') || abiStr.contains('x86_64')) return 'x86_64';
      if (abiStr.contains('ia32') || abiStr.contains('x86')) return 'x86';
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>?> getLatestReleaseInfo() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/Skyleaft/Open-Manga-Reader/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String latestVersion =
            (data['tag_name'] as String).replaceAll('v', '').trim();

        final packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;
        final bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);

        final rawAssets = (data['assets'] as List<dynamic>?) ?? [];
        final matchedAsset = _findMatchingAsset(rawAssets);

        return {
          'hasUpdate': hasUpdate,
          'currentVersion': currentVersion,
          'version': data['tag_name'],
          'latestVersion': data['tag_name'],
          'body': data['body'],
          'url': data['html_url'],
          'downloadUrl': matchedAsset?['browser_download_url'],
          'fileName': matchedAsset?['name'],
          'fileSize': (matchedAsset?['size'] as num?)?.toInt() ?? 0,
          'targetAbi': getAndroidAbi(),
        };
      }
    } catch (e) {
      debugPrint('Failed to check for updates: $e');
    }
    return null;
  }

  Map<String, dynamic>? _findMatchingAsset(List<dynamic> assets) {
    if (assets.isEmpty) return null;

    final assetList = assets.whereType<Map<String, dynamic>>().toList();

    if (!kIsWeb && Platform.isAndroid) {
      final apkAssets = assetList
          .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
          .toList();

      if (apkAssets.isEmpty) return null;

      final targetAbi = getAndroidAbi().toLowerCase();

      // 1. Exact match on ABI (e.g. arm64-v8a)
      if (targetAbi.isNotEmpty) {
        for (final asset in apkAssets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.contains(targetAbi)) {
            return asset;
          }
        }
      }

      // 2. Fallback to universal APK
      for (final asset in apkAssets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.contains('universal')) {
          return asset;
        }
      }

      // 3. Fallback to first available APK
      return apkAssets.first;
    } else if (!kIsWeb && Platform.isWindows) {
      for (final asset in assetList) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.exe') || name.endsWith('.msix') || name.endsWith('.zip')) {
          return asset;
        }
      }
    }

    return assetList.isNotEmpty ? assetList.first : null;
  }

  /// Download file update dengan progress callback
  Future<String?> downloadUpdate({
    required String downloadUrl,
    required String fileName,
    required void Function(double progress, int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';

      final file = File(savePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      await _dio.download(
        downloadUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            onProgress(progress, received, total);
          }
        },
      );

      return savePath;
    } catch (e) {
      debugPrint('Error downloading update file: $e');
      return null;
    }
  }

  /// Install APK secara native di Android
  Future<bool> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error installing APK: $e');
      return false;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    final info = await getLatestReleaseInfo();
    if (info != null && info['hasUpdate'] == true) {
      return info;
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final v1 = current
          .split('+')[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final v2 = latest
          .split('+')[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      for (int i = 0; i < 3; i++) {
        final part1 = i < v1.length ? v1[i] : 0;
        final part2 = i < v2.length ? v2[i] : 0;
        if (part2 > part1) return true;
        if (part2 < part1) return false;
      }
    } catch (e) {
      debugPrint("Version parse error: $e");
    }
    return false;
  }
}
