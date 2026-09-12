// ignore_for_file: depend_on_referenced_packages
import 'package:file/file.dart' as pkg_file;
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:my_manga_reader/core/network/manga_api_service.dart';
import 'package:my_manga_reader/features/library/models/library_manga.dart';
import 'package:my_manga_reader/features/library/services/library_cache_service.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';
import 'package:my_manga_reader/features/manga_detail/services/manga_detail_service.dart';

class FakeCacheManager implements BaseCacheManager {
  final List<String> downloadedUrls = [];
  final MemoryFileSystem _fs = MemoryFileSystem();

  @override
  Future<pkg_file.File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    downloadedUrls.add(url);
    return _fs.file('/dummy_path');
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMangaApiService implements MangaApiService {
  final Map<String, dynamic> mangaDetailResponse;

  FakeMangaApiService({required this.mangaDetailResponse});

  @override
  String getLocalImageUrl(String? localPath, String? remotePath) {
    return 'https://cdn.example.com/${localPath ?? remotePath}';
  }

  @override
  Future<Map<String, dynamic>> getMangaDetail(String mangaId, {dynamic cancelToken}) async {
    return mangaDetailResponse;
  }

  @override
  Future<List<Map<String, dynamic>>> getMangaChapters(String mangaId, {dynamic cancelToken}) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMangaDetailService implements MangaDetailService {
  final Map<String, MangaDetail> stored = {};

  @override
  Future<MangaDetail?> getDetail(String mangaId) async => stored[mangaId];

  @override
  Future<void> saveDetail(MangaDetail detail) async {
    stored[detail.id] = detail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LibraryCacheService Tests', () {
    test('cacheAllLibraryData downloads cover and saves detail', () async {
      final fakeCache = FakeCacheManager();
      final fakeApi = FakeMangaApiService(
        mangaDetailResponse: {
          'id': 'manga-1',
          'malId': 101,
          'title': 'Solo Leveling',
          'author': 'Chugong',
          'type': 'Manhwa',
          'imageUrl': 'covers/sl.jpg',
          'chapters': [
            {'id': 'ch-1', 'title': 'Chapter 1', 'chapterNumber': 1.0}
          ],
        },
      );
      final fakeDetailService = FakeMangaDetailService();

      final service = LibraryCacheService(
        apiService: fakeApi,
        detailService: fakeDetailService,
        cacheManager: fakeCache,
      );

      final manga = LibraryManga(
        id: 'manga-1',
        title: 'Solo Leveling',
        author: 'Chugong',
        imageUrl: 'covers/sl.jpg',
        addedAt: DateTime.now(),
        currentChapter: 1,
        currentPage: 1,
        totalPages: 20,
        isCompleted: false,
      );

      await service.cacheAllLibraryData([manga]);

      expect(fakeCache.downloadedUrls, contains('https://cdn.example.com/covers/sl.jpg'));
      expect(fakeDetailService.stored.containsKey('manga-1'), isTrue);
      expect(fakeDetailService.stored['manga-1']!.title, 'Solo Leveling');
      expect(fakeDetailService.stored['manga-1']!.chapters.length, 1);
      expect(service.progress, 1.0);
      expect(service.lastFullCacheTime, isNotNull);

      // Second call immediately should be skipped due to cooldown
      fakeCache.downloadedUrls.clear();
      await service.cacheAllLibraryData([manga]);
      expect(fakeCache.downloadedUrls, isEmpty);

      // Unless force: true
      await service.cacheAllLibraryData([manga], force: true);
      expect(fakeCache.downloadedUrls, contains('https://cdn.example.com/covers/sl.jpg'));
    });
  });
}
