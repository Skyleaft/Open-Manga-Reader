import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/services/network_status_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../models/library_manga.dart';

class LibraryCacheService {
  final MangaApiService _apiService;
  final MangaDetailService _detailService;
  final BaseCacheManager _cacheManager;

  final ValueNotifier<bool> isCachingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);

  bool get isCaching => isCachingNotifier.value;
  double get progress => progressNotifier.value;

  final Duration cooldownDuration;
  DateTime? _lastFullCacheTime;

  DateTime? get lastFullCacheTime => _lastFullCacheTime;

  LibraryCacheService({
    MangaApiService? apiService,
    MangaDetailService? detailService,
    BaseCacheManager? cacheManager,
    this.cooldownDuration = const Duration(hours: 6),
  })  : _apiService = apiService ?? getIt<MangaApiService>(),
        _detailService = detailService ?? getIt<MangaDetailService>(),
        _cacheManager = cacheManager ?? DefaultCacheManager();

  bool _cancelRequested = false;

  /// Caches all covers and full manga details for the given [library] mangas.
  Future<void> cacheAllLibraryData(
    List<LibraryManga> library, {
    bool force = false,
  }) async {
    if (library.isEmpty || isCaching) return;

    // Skip if within cooldown period unless forced
    if (!force &&
        _lastFullCacheTime != null &&
        DateTime.now().difference(_lastFullCacheTime!) < cooldownDuration) {
      debugPrint(
        '[LibraryCacheService] Pre-cache cooldown active (last run: ${_lastFullCacheTime!.toIso8601String()}), skipping.',
      );
      return;
    }

    // Skip if offline
    if (getIt.isRegistered<NetworkStatusService>() &&
        !getIt<NetworkStatusService>().isOnline) {
      debugPrint('[LibraryCacheService] Offline mode: skipping pre-cache');
      return;
    }

    _cancelRequested = false;
    isCachingNotifier.value = true;
    progressNotifier.value = 0.0;

    debugPrint(
      '[LibraryCacheService] Starting pre-cache for ${library.length} library manga...',
    );

    int completed = 0;
    final total = library.length;

    for (final manga in library) {
      if (_cancelRequested) break;

      // Stop if network went offline midway
      if (getIt.isRegistered<NetworkStatusService>() &&
          !getIt<NetworkStatusService>().isOnline) {
        debugPrint('[LibraryCacheService] Network disconnected, pausing cache');
        break;
      }

      await _cacheSingleMangaInternal(manga);

      completed++;
      progressNotifier.value = completed / total;

      // Rate limit protection: small pause between items
      if (completed < total) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    isCachingNotifier.value = false;
    _lastFullCacheTime = DateTime.now();
    debugPrint(
      '[LibraryCacheService] Pre-cache completed ($completed/$total processed)',
    );
  }

  /// Pre-caches cover and detail for a single manga item (e.g. when added to library).
  Future<void> cacheSingleManga(LibraryManga manga) async {
    if (getIt.isRegistered<NetworkStatusService>() &&
        !getIt<NetworkStatusService>().isOnline) {
      return;
    }
    await _cacheSingleMangaInternal(manga);
  }

  Future<void> _cacheSingleMangaInternal(LibraryManga manga) async {
    try {
      // 1. Cache Cover Image
      await cacheMangaCover(manga.imageUrl);

      // 2. Cache Manga Detail & Chapters
      MangaDetail? detail = await _detailService.getDetail(manga.id);

      if (detail == null || detail.chapters.isEmpty) {
        try {
          final detailData = await _apiService.getMangaDetail(manga.id);
          var fetchedDetail = MangaDetail.fromMap(detailData);

          if (fetchedDetail.chapters.isEmpty) {
            try {
              final chaptersData =
                  await _apiService.getMangaChapters(manga.id);
              final chapters =
                  chaptersData.map((e) => Chapter.fromMap(e)).toList();
              fetchedDetail = fetchedDetail.copyWith(chapters: chapters);
            } catch (_) {}
          }

          await _detailService.saveDetail(fetchedDetail);
          detail = fetchedDetail;
        } catch (e) {
          debugPrint(
            '[LibraryCacheService] Failed to fetch detail for "${manga.title}": $e',
          );
        }
      }

      // 3. Cache detail cover if localImageUrl exists
      if (detail != null &&
          detail.localImageUrl != null &&
          detail.localImageUrl!.isNotEmpty) {
        await cacheMangaCover(detail.localImageUrl!);
      }
    } catch (e) {
      debugPrint(
        '[LibraryCacheService] Error caching manga "${manga.title}": $e',
      );
    }
  }

  /// Pre-caches a single cover image into the disk cache.
  Future<void> cacheMangaCover(String imagePath) async {
    if (imagePath.isEmpty) return;
    try {
      final fullUrl = _apiService.getLocalImageUrl(imagePath, imagePath);
      if (fullUrl.isNotEmpty && fullUrl.startsWith('http')) {
        final existing = await _cacheManager.getFileFromCache(fullUrl);
        if (existing != null && await existing.file.exists()) {
          return;
        }
        await _cacheManager.getSingleFile(fullUrl);
      }
    } catch (e) {
      debugPrint('[LibraryCacheService] Failed to cache image $imagePath: $e');
    }
  }

  void cancel() {
    _cancelRequested = true;
  }

  void dispose() {
    cancel();
    isCachingNotifier.dispose();
    progressNotifier.dispose();
  }
}
