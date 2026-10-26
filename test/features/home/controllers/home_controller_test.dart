import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/manga_summary.dart';
import 'package:my_manga_reader/core/models/paged_response.dart';
import 'package:my_manga_reader/core/network/manga_api_service.dart';
import 'package:my_manga_reader/features/history/models/progression.dart';
import 'package:my_manga_reader/features/history/services/progression_service.dart';
import 'package:my_manga_reader/features/home/controllers/home_controller.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';
import 'package:my_manga_reader/features/manga_detail/services/manga_detail_service.dart';

class FakeProgressionService extends ProgressionService {
  bool forceSyncCalled = false;
  List<MangaProgression> mockProgressions = [];

  @override
  Future<List<MangaProgression>> getAllProgressions({bool forceSync = false}) async {
    if (forceSync) {
      forceSyncCalled = true;
    }
    return List<MangaProgression>.from(mockProgressions);
  }
}

class FakeMangaDetailService extends MangaDetailService {
  @override
  Future<MangaDetail?> getDetail(String mangaId) async => null;

  @override
  Future<void> saveDetail(MangaDetail detail) async {}
}

class FakeMangaApiService extends MangaApiService {
  @override
  Future<PagedResponse<MangaSummary>> getTrending({
    String? search,
    List<String>? genres,
    String? status,
    String? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    return PagedResponse(items: [], totalPages: 0, totalCount: 0, page: 1, pageSize: 10);
  }

  @override
  Future<PagedResponse<MangaSummary>> getPagedManga({
    String? search,
    String? status,
    String? type,
    String? sortBy,
    String? orderBy,
    List<String>? genres,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return PagedResponse(items: [], totalPages: 0, totalCount: 0, page: 1, pageSize: pageSize);
  }

  @override
  Future<List<MangaSummary>> getRecommendations({
    List<String>? readingHistoryIds,
    int limit = 6,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getMangaDetail(
    String mangaId, {
    CancelToken? cancelToken,
  }) async {
    return {
      'id': mangaId,
      'title': 'Test Manga',
      'coverUrl': 'https://example.com/cover.jpg',
      'chapters': [],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeController Progression Sync Tests', () {
    late FakeProgressionService fakeProgressionService;
    late FakeMangaApiService fakeApiService;
    late FakeMangaDetailService fakeDetailService;

    setUp(() {
      fakeProgressionService = FakeProgressionService();
      fakeApiService = FakeMangaApiService();
      fakeDetailService = FakeMangaDetailService();
    });

    test('fetchAllData(syncProgressionFirst: true) forces sync on progression first', () async {
      fakeProgressionService.mockProgressions = [
        MangaProgression(
          id: 'prog-1',
          userId: 'user-1',
          mangaId: 'manga-1',
          lastReadAt: DateTime.now(),
          totalReadingTime: 120,
          chapterLogs: [
            UserChapterLog(
              id: 'log-1',
              chapterId: 'ch-1',
              chapterNumber: 1.0,
              lastReadPage: 10,
              totalPages: 20,
              isCompleted: false,
              readingTimeSeconds: 120,
              lastReadAt: DateTime.now(),
            ),
          ],
        ),
      ];

      final controller = HomeController(
        apiService: fakeApiService,
        progressionService: fakeProgressionService,
        detailService: fakeDetailService,
      );

      expect(fakeProgressionService.forceSyncCalled, isFalse);

      await controller.fetchAllData(syncProgressionFirst: true);

      expect(fakeProgressionService.forceSyncCalled, isTrue);
      expect(controller.recentProgressions.length, 1);
      expect(controller.recentProgressions.first.mangaId, 'manga-1');

      controller.dispose();
    });

    test('fetchHistory with forceSync calls progression service with forceSync: true', () async {
      final controller = HomeController(
        apiService: fakeApiService,
        progressionService: fakeProgressionService,
        detailService: fakeDetailService,
      );

      await controller.fetchHistory(forceSync: true);

      expect(fakeProgressionService.forceSyncCalled, isTrue);

      controller.dispose();
    });
  });
}
