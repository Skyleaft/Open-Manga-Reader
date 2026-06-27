import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_manga.dart';
import '../models/progression.dart';
import '../../core/di/injection.dart';
import 'manga_api_service.dart';
import 'sync_service.dart';

class LibraryService {
  static const _libraryKey = 'manga_library';

  Future<void> addToLibrary(LibraryManga manga) async {
    // 1. Update local cache
    await _updateLocalCache(manga, isRemoving: false);

    // 2. Try API
    final apiService = getIt<MangaApiService>();
    try {
      await apiService.addToUserLibrary(manga.toApiRequest());
    } catch (e) {
      // 3. Queue for sync if failed
      getIt<SyncService>().enqueueAction('library_add', manga.toApiRequest());
    }
  }

  Future<void> removeFromLibrary(String mangaId) async {
    // 1. Update local cache
    await _updateLocalCacheById(mangaId, isRemoving: true);

    // 2. Try API
    final apiService = getIt<MangaApiService>();
    try {
      await apiService.removeFromUserLibrary(mangaId);
    } catch (e) {
      // 3. Queue for sync if failed
      getIt<SyncService>().enqueueAction('library_remove', {'mangaId': mangaId});
    }
  }

  Future<LibraryManga?> getLibraryManga(String mangaId) async {
    final library = await getAllLibraryMangas();
    try {
      return library.firstWhere((m) => m.id == mangaId);
    } catch (_) {
      return null;
    }
  }

  Future<List<LibraryManga>> getAllLibraryMangas() async {
    final apiService = getIt<MangaApiService>();
    final syncService = getIt<SyncService>();

    // 1. Return local cache immediately for instant offline access
    final localLibrary = await _loadFromLocalCache();

    // 2. Try to sync with API in the background
    _syncLibraryFromApi(apiService, syncService);

    return localLibrary;
  }

  /// Fires a background sync — updates the local cache from the API without
  /// blocking the caller. Errors are silently swallowed since the caller
  /// already has the local data.
  Future<void> _syncLibraryFromApi(
    MangaApiService apiService,
    SyncService syncService,
  ) async {
    try {
      final libraryData = await apiService.getUserLibrary();
      final progressionData = await apiService.getUserProgression();

      final progressions = progressionData
          .map((e) => MangaProgression.fromMap(e))
          .toList();

      final library = libraryData.map((e) {
        final libraryModel = LibraryManga.fromMap(e);
        MangaProgression? progression;
        try {
          progression = progressions.firstWhere((p) => p.mangaId == libraryModel.id);
        } catch (_) {}

        if (progression != null) {
          return libraryModel.copyWith(
            currentChapter: progression.currentChapter,
            currentPage: progression.currentPage,
            totalPages: progression.totalPages,
            isCompleted: progression.isCompleted,
          );
        }
        return libraryModel;
      }).toList();

      await _saveAllToLocalCache(library);
      syncService.syncPendingActions();
    } catch (_) {
      // Silently ignore — we already returned the cached data
    }
  }

  /// Fetches all library data from the API and updates local cache.
  /// Public wrapper — call and await this to ensure data is refreshed from the server.
  Future<void> refreshFromApi() async {
    final apiService = getIt<MangaApiService>();
    final syncService = getIt<SyncService>();
    await _syncLibraryFromApi(apiService, syncService);
  }

  Future<bool> isInLibrary(String mangaId) async {
    final library = await getAllLibraryMangas();
    return library.any((m) => m.id == mangaId);
  }

  Future<void> updateMangaProgress(
    String mangaId,
    double currentChapter,
    int currentPage,
    int totalPages,
    bool isCompleted,
  ) async {
    final apiService = getIt<MangaApiService>();
    final payload = {
      'mangaId': mangaId,
      'chapterNumber': currentChapter,
      'lastReadPage': currentPage,
      'totalPages': totalPages,
    };

    // 1. Update local cache (find and update)
    final library = await _loadFromLocalCache();
    final index = library.indexWhere((m) => m.id == mangaId);
    if (index >= 0) {
      library[index] = library[index].copyWith(
        currentChapter: currentChapter,
        currentPage: currentPage,
        totalPages: totalPages,
        isCompleted: isCompleted,
      );
      await _saveAllToLocalCache(library);
    }

    // 2. Try API
    try {
      await apiService.updateUserProgression(payload);
    } catch (e) {
      // 3. Queue for sync if failed
      getIt<SyncService>().enqueueAction('progression_update', payload);
    }
  }

  Future<void> clearLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_libraryKey);
  }

  // Helper methods for local cache

  Future<void> _updateLocalCache(LibraryManga manga, {required bool isRemoving}) async {
    final library = await _loadFromLocalCache();
    final index = library.indexWhere((m) => m.id == manga.id);

    if (isRemoving) {
      if (index >= 0) library.removeAt(index);
    } else {
      if (index >= 0) {
        library[index] = manga;
      } else {
        library.add(manga);
      }
    }
    await _saveAllToLocalCache(library);
  }

  Future<void> _updateLocalCacheById(String mangaId, {required bool isRemoving}) async {
    final library = await _loadFromLocalCache();
    final index = library.indexWhere((m) => m.id == mangaId);

    if (isRemoving && index >= 0) {
      library.removeAt(index);
      await _saveAllToLocalCache(library);
    }
  }

  Future<void> _saveAllToLocalCache(List<LibraryManga> library) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = library.map((m) => m.toJson()).toList();
    await prefs.setStringList(_libraryKey, jsonList);
  }

  Future<List<LibraryManga>> _loadFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_libraryKey) ?? [];
    return jsonList.map((json) => LibraryManga.fromJson(json)).toList();
  }
}
