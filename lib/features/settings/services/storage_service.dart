import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/di/injection.dart';
import '../../manga_detail/services/manga_detail_service.dart';

class StorageUsageInfo {
  final int cacheBytes;
  final int downloadsBytes;
  final int dataBytes;

  int get totalBytes => cacheBytes + downloadsBytes + dataBytes;

  const StorageUsageInfo({
    required this.cacheBytes,
    required this.downloadsBytes,
    required this.dataBytes,
  });
}

class StorageService {
  Future<StorageUsageInfo> getStorageUsage() async {
    int cacheBytes = 0;
    int downloadsBytes = 0;
    int dataBytes = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      cacheBytes += await _getDirectorySize(tempDir);
    } catch (_) {}

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docDir.path}/downloads');
      if (await downloadsDir.exists()) {
        downloadsBytes = await _getDirectorySize(downloadsDir);
      }
      dataBytes += await _getDirectorySize(docDir) - downloadsBytes;
    } catch (_) {}

    try {
      final supportDir = await getApplicationSupportDirectory();
      dataBytes += await _getDirectorySize(supportDir);
    } catch (_) {}

    if (dataBytes < 0) dataBytes = 0;

    return StorageUsageInfo(
      cacheBytes: cacheBytes,
      downloadsBytes: downloadsBytes,
      dataBytes: dataBytes,
    );
  }

  Future<int> getCacheSizeBytes() async {
    int size = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      size = await _getDirectorySize(tempDir);
    } catch (_) {}
    return size;
  }

  Future<int> getDownloadsSizeBytes() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docDir.path}/downloads');
      if (await downloadsDir.exists()) {
        return await _getDirectorySize(downloadsDir);
      }
    } catch (_) {}
    return 0;
  }

  Future<void> clearCache() async {
    // 1. Clear Flutter Image Cache in memory
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // 2. Clear temporary directory files
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = tempDir.listSync(recursive: false);
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. Clear Hive manga detail cache
    try {
      if (getIt.isRegistered<MangaDetailService>()) {
        await getIt<MangaDetailService>().clearAll();
      }
    } catch (_) {}
  }

  Future<void> clearDownloads() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docDir.path}/downloads');
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<Directory> getDownloadsDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${docDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int totalSize = 0;
    try {
      if (!await dir.exists()) return 0;
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return totalSize;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
