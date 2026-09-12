import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/models/chapter_page.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/storage/hive_storage.dart';
import '../../../core/utils/url_utils.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../settings/services/storage_service.dart';
import '../models/downloaded_chapter.dart';

class DownloadedMangaGroup {
  final String mangaId;
  final String mangaTitle;
  final String? mangaCoverUrl;
  final List<DownloadedChapter> chapters;

  const DownloadedMangaGroup({
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCoverUrl,
    required this.chapters,
  });

  int get totalSizeBytes =>
      chapters.fold<int>(0, (sum, ch) => sum + ch.sizeBytes);

  String get formattedTotalSize => StorageService.formatBytes(totalSizeBytes);
  int get chapterCount => chapters.length;
}

class DownloadService {
  final MangaApiService _apiService;
  final StorageService _storageService;
  final Dio _dio;

  final ValueNotifier<Map<String, DownloadTask>> tasksNotifier =
      ValueNotifier<Map<String, DownloadTask>>({});

  final Map<String, CancelToken> _cancelTokens = {};
  bool _isProcessingQueue = false;
  static const int _maxConcurrent = 2;
  int _activeCount = 0;

  DownloadService({
    MangaApiService? apiService,
    StorageService? storageService,
    Dio? dio,
  })  : _apiService = apiService ?? getIt<MangaApiService>(),
        _storageService = storageService ?? getIt<StorageService>(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );

  // ---------------------------------------------------------------------------
  // Status Queries
  // ---------------------------------------------------------------------------

  bool isChapterDownloaded(String mangaId, String chapterId) {
    try {
      final key = '${mangaId}_$chapterId';
      return HiveStorage.downloadsBox.containsKey(key);
    } catch (_) {
      return false;
    }
  }

  DownloadedChapter? getDownloadedChapter(String mangaId, String chapterId) {
    try {
      final key = '${mangaId}_$chapterId';
      final raw = HiveStorage.downloadsBox.get(key);
      if (raw == null) return null;
      if (raw is Map) {
        return DownloadedChapter.fromMap(Map<String, dynamic>.from(raw));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  DownloadTask? getTask(String chapterId) {
    return tasksNotifier.value[chapterId];
  }

  List<DownloadedMangaGroup> getDownloadsGroupedByManga() {
    final Map<String, List<DownloadedChapter>> grouped = {};
    final Map<String, String> titles = {};
    final Map<String, String?> covers = {};

    final box = HiveStorage.downloadsBox;
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw is Map) {
          final ch = DownloadedChapter.fromMap(Map<String, dynamic>.from(raw));
          grouped.putIfAbsent(ch.mangaId, () => []).add(ch);
          titles[ch.mangaId] = ch.mangaTitle;
          if (ch.mangaCoverUrl != null && ch.mangaCoverUrl!.isNotEmpty) {
            covers[ch.mangaId] = ch.mangaCoverUrl;
          }
        }
      } catch (_) {}
    }

    final List<DownloadedMangaGroup> result = [];
    grouped.forEach((mangaId, chapters) {
      // Sort chapters ascending by chapterNumber
      chapters.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
      result.add(
        DownloadedMangaGroup(
          mangaId: mangaId,
          mangaTitle: titles[mangaId] ?? 'Manga $mangaId',
          mangaCoverUrl: covers[mangaId],
          chapters: chapters,
        ),
      );
    });

    result.sort((a, b) => a.mangaTitle.compareTo(b.mangaTitle));
    return result;
  }

  int getTotalDownloadedBytes() {
    final box = HiveStorage.downloadsBox;
    int total = 0;
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw is Map) {
          final size = raw['sizeBytes'] as int? ?? 0;
          total += size;
        }
      } catch (_) {}
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Enqueue Downloads
  // ---------------------------------------------------------------------------

  Future<void> downloadChapter(MangaDetail manga, Chapter chapter) async {
    if (isChapterDownloaded(manga.id, chapter.id)) {
      return; // Already downloaded
    }

    final currentTask = tasksNotifier.value[chapter.id];
    if (currentTask != null &&
        (currentTask.isDownloading || currentTask.isQueued)) {
      return; // Already in progress
    }

    final task = DownloadTask(
      mangaId: manga.id,
      mangaTitle: manga.title,
      mangaCoverUrl: manga.imageUrl ?? manga.localImageUrl,
      chapter: chapter,
      status: DownloadStatus.queued,
      totalPages: chapter.pageCount > 0 ? chapter.pageCount : chapter.pages.length,
    );

    final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
    updated[chapter.id] = task;
    tasksNotifier.value = updated;

    _processQueue();
  }

  Future<void> downloadChapters(
    MangaDetail manga,
    List<Chapter> chapters,
  ) async {
    final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
    for (final ch in chapters) {
      if (!isChapterDownloaded(manga.id, ch.id)) {
        final current = updated[ch.id];
        if (current == null ||
            (!current.isDownloading && !current.isQueued)) {
          updated[ch.id] = DownloadTask(
            mangaId: manga.id,
            mangaTitle: manga.title,
            mangaCoverUrl: manga.imageUrl ?? manga.localImageUrl,
            chapter: ch,
            status: DownloadStatus.queued,
            totalPages: ch.pageCount > 0 ? ch.pageCount : ch.pages.length,
          );
        }
      }
    }
    tasksNotifier.value = updated;
    _processQueue();
  }

  void cancelDownload(String chapterId) {
    _cancelTokens[chapterId]?.cancel('Cancelled by user');
    _cancelTokens.remove(chapterId);

    final task = tasksNotifier.value[chapterId];
    if (task != null) {
      final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
      updated[chapterId] = task.copyWith(
        status: DownloadStatus.canceled,
        errorMessage: 'Download canceled',
      );
      tasksNotifier.value = updated;
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Processor
  // ---------------------------------------------------------------------------

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_activeCount < _maxConcurrent) {
        final nextQueued = tasksNotifier.value.values
            .where((t) => t.isQueued)
            .firstOrNull;

        if (nextQueued == null) break;

        _activeCount++;
        _runDownload(nextQueued);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _runDownload(DownloadTask task) async {
    final chapterId = task.chapter.id;
    final mangaId = task.mangaId;
    final cancelToken = CancelToken();
    _cancelTokens[chapterId] = cancelToken;

    _updateTaskStatus(
      chapterId,
      status: DownloadStatus.downloading,
      progress: 0.0,
      downloadedPages: 0,
    );

    try {
      // 1. Fetch pages if needed
      List<ChapterPage> pages = task.chapter.pages;
      if (pages.isEmpty) {
        pages = await _apiService.getChapterPages(
          mangaId,
          chapterId,
          cancelToken: cancelToken,
        );
      }

      if (pages.isEmpty) {
        throw Exception('Chapter contains no pages to download.');
      }

      final totalPages = pages.length;
      _updateTaskStatus(
        chapterId,
        status: DownloadStatus.downloading,
        totalPages: totalPages,
      );

      // 2. Prepare directory
      final baseDir = await _storageService.getDownloadsDirectory();
      final chapterDirPath = UrlUtils.normalizeLocalFilePath(
        '${baseDir.path}/$mangaId/$chapterId',
      );
      final chapterDir = Directory(chapterDirPath);
      if (!await chapterDir.exists()) {
        await chapterDir.create(recursive: true);
      }

      // 3. Download page images
      final List<String> downloadedFilePaths = [];
      int totalSizeBytes = 0;

      for (int i = 0; i < pages.length; i++) {
        if (cancelToken.isCancelled) {
          throw DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.cancel,
          );
        }

        final page = pages[i];
        final ext = _getImageExtension(page.url);
        final fileName = '${(i + 1).toString().padLeft(3, '0')}$ext';
        final filePath = UrlUtils.normalizeLocalFilePath(
          '${chapterDir.path}/$fileName',
        );
        final file = File(filePath);

        // Download or use existing if already on disk
        if (await file.exists() && await file.length() > 0) {
          totalSizeBytes += await file.length();
          downloadedFilePaths.add(filePath);
        } else {
          final targetUrl = _apiService.getLocalImageUrl(page.url, null);
          try {
            await _dio.download(
              targetUrl,
              filePath,
              cancelToken: cancelToken,
            );
          } catch (err) {
            // Try fallback URL if available
            if (page.alternateUrl != null &&
                page.alternateUrl!.isNotEmpty &&
                !cancelToken.isCancelled) {
              final altUrl =
                  _apiService.getLocalImageUrl(page.alternateUrl!, null);
              await _dio.download(
                altUrl,
                filePath,
                cancelToken: cancelToken,
              );
            } else {
              rethrow;
            }
          }

          if (await file.exists()) {
            totalSizeBytes += await file.length();
            downloadedFilePaths.add(filePath);
          }
        }

        _updateTaskStatus(
          chapterId,
          downloadedPages: i + 1,
          totalPages: totalPages,
          progress: (i + 1) / totalPages,
          sizeBytes: totalSizeBytes,
        );
      }

      // 4. Save metadata to Hive
      final downloadedChapter = DownloadedChapter(
        mangaId: mangaId,
        mangaTitle: task.mangaTitle,
        mangaCoverUrl: task.mangaCoverUrl,
        chapterId: chapterId,
        chapterNumber: task.chapter.chapterNumber,
        chapterTitle: task.chapter.title,
        pageCount: downloadedFilePaths.length,
        sizeBytes: totalSizeBytes,
        downloadedAt: DateTime.now(),
        pageFilePaths: downloadedFilePaths,
      );

      await HiveStorage.downloadsBox.put(
        '${mangaId}_$chapterId',
        downloadedChapter.toMap(),
      );

      _updateTaskStatus(
        chapterId,
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedPages: downloadedFilePaths.length,
        sizeBytes: totalSizeBytes,
      );
    } catch (e) {
      if (cancelToken.isCancelled) {
        _updateTaskStatus(
          chapterId,
          status: DownloadStatus.canceled,
          errorMessage: 'Download canceled',
        );
      } else {
        _updateTaskStatus(
          chapterId,
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
      }
    } finally {
      _cancelTokens.remove(chapterId);
      _activeCount--;
      _processQueue();
    }
  }

  void _updateTaskStatus(
    String chapterId, {
    DownloadStatus? status,
    double? progress,
    int? downloadedPages,
    int? totalPages,
    String? errorMessage,
    int? sizeBytes,
  }) {
    final current = tasksNotifier.value[chapterId];
    if (current == null) return;

    final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
    updated[chapterId] = current.copyWith(
      status: status,
      progress: progress,
      downloadedPages: downloadedPages,
      totalPages: totalPages,
      errorMessage: errorMessage,
      sizeBytes: sizeBytes,
    );
    tasksNotifier.value = updated;
  }

  String _getImageExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.png')) return '.png';
      if (path.endsWith('.webp')) return '.webp';
      if (path.endsWith('.avif')) return '.avif';
      if (path.endsWith('.gif')) return '.gif';
      if (path.endsWith('.jpeg')) return '.jpg';
      if (path.endsWith('.jpg')) return '.jpg';
    } catch (_) {}
    return '.jpg';
  }

  // ---------------------------------------------------------------------------
  // Deletion Management
  // ---------------------------------------------------------------------------

  Future<void> deleteDownloadedChapter(
    String mangaId,
    String chapterId,
  ) async {
    cancelDownload(chapterId);

    try {
      final baseDir = await _storageService.getDownloadsDirectory();
      final chapterDirPath = UrlUtils.normalizeLocalFilePath(
        '${baseDir.path}/$mangaId/$chapterId',
      );
      final chapterDir = Directory(chapterDirPath);
      if (await chapterDir.exists()) {
        await chapterDir.delete(recursive: true);
      }

      final key = '${mangaId}_$chapterId';
      await HiveStorage.downloadsBox.delete(key);

      // Clean task from state
      final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
      updated.remove(chapterId);
      tasksNotifier.value = updated;
    } catch (e) {
      debugPrint('[DownloadService] Error deleting chapter $chapterId: $e');
    }
  }

  Future<void> deleteMangaDownloads(String mangaId) async {
    try {
      final baseDir = await _storageService.getDownloadsDirectory();
      final mangaDirPath = UrlUtils.normalizeLocalFilePath(
        '${baseDir.path}/$mangaId',
      );
      final mangaDir = Directory(mangaDirPath);
      if (await mangaDir.exists()) {
        await mangaDir.delete(recursive: true);
      }

      final box = HiveStorage.downloadsBox;
      final keysToDelete = box.keys
          .where((k) => k.toString().startsWith('${mangaId}_'))
          .toList();

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      final updated = Map<String, DownloadTask>.from(tasksNotifier.value);
      updated.removeWhere((_, task) => task.mangaId == mangaId);
      tasksNotifier.value = updated;
    } catch (e) {
      debugPrint('[DownloadService] Error deleting manga downloads $mangaId: $e');
    }
  }

  Future<void> deleteAllDownloads() async {
    try {
      for (final token in _cancelTokens.values) {
        token.cancel('Delete all');
      }
      _cancelTokens.clear();

      await _storageService.clearDownloads();
      await HiveStorage.downloadsBox.clear();

      tasksNotifier.value = {};
    } catch (e) {
      debugPrint('[DownloadService] Error deleting all downloads: $e');
    }
  }
}
