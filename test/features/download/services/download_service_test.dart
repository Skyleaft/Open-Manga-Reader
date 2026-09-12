import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:my_manga_reader/core/network/manga_api_service.dart';
import 'package:my_manga_reader/core/storage/hive_storage.dart';
import 'package:my_manga_reader/features/download/models/downloaded_chapter.dart';
import 'package:my_manga_reader/features/download/services/download_service.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';
import 'package:my_manga_reader/features/settings/services/storage_service.dart';

class FakeMangaApiService implements MangaApiService {
  @override
  String getLocalImageUrl(String? localPath, String? remotePath) {
    return 'https://example.com/${localPath ?? remotePath}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageService implements StorageService {
  final Directory tempDir;

  FakeStorageService(this.tempDir);

  @override
  Future<Directory> getDownloadsDirectory() async {
    final dir = Directory('${tempDir.path}/downloads');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory tempDir;
  late Box downloadsBox;
  late FakeMangaApiService fakeApi;
  late FakeStorageService fakeStorage;
  late DownloadService downloadService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('download_service_test_');
    Hive.init(tempDir.path);
    downloadsBox = await Hive.openBox(HiveStorage.downloadsBoxName);
    fakeApi = FakeMangaApiService();
    fakeStorage = FakeStorageService(tempDir);
    downloadService = DownloadService(
      apiService: fakeApi,
      storageService: fakeStorage,
    );
  });

  tearDown(() async {
    await downloadsBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DownloadedChapter Model Tests', () {
    test('DownloadedChapter serialization to and from Map', () {
      final downloaded = DownloadedChapter(
        chapterId: 'ch-1',
        mangaId: 'm-1',
        mangaTitle: 'Test Manga',
        mangaCoverUrl: 'https://example.com/cover.jpg',
        chapterTitle: 'Chapter 1',
        chapterNumber: 1.0,
        pageCount: 2,
        pageFilePaths: ['/path/to/page1.jpg', '/path/to/page2.jpg'],
        sizeBytes: 2048,
        downloadedAt: DateTime(2026, 1, 1),
      );

      final map = downloaded.toMap();
      final fromMap = DownloadedChapter.fromMap(map);

      expect(fromMap.chapterId, 'ch-1');
      expect(fromMap.mangaId, 'm-1');
      expect(fromMap.mangaTitle, 'Test Manga');
      expect(fromMap.chapterNumber, 1.0);
      expect(fromMap.pageCount, 2);
      expect(fromMap.pageFilePaths.length, 2);
      expect(fromMap.sizeBytes, 2048);
      expect(fromMap.formattedSize, isNotEmpty);
      expect(fromMap.isComplete, isTrue);
      expect(fromMap.toChapterPages().length, 2);
    });

    test('DownloadTask copyWith and progress calculation', () {
      final chapter = Chapter(
        id: 'ch-1',
        title: 'Chapter 1',
        chapterNumber: 1.0,
        date: DateTime(2026, 1, 1),
        totalPages: 10,
      );
      final task = DownloadTask(
        mangaId: 'm-1',
        mangaTitle: 'Test Manga',
        chapter: chapter,
      );

      expect(task.status, DownloadStatus.queued);
      expect(task.progress, 0.0);
      expect(task.chapter.id, 'ch-1');

      final runningTask = task.copyWith(
        status: DownloadStatus.downloading,
        downloadedPages: 5,
        totalPages: 10,
      );

      expect(runningTask.status, DownloadStatus.downloading);
      expect(runningTask.downloadedPages, 5);
      expect(runningTask.totalPages, 10);
      expect(runningTask.progress, 0.5);
    });
  });

  group('DownloadService Tests', () {
    test('isChapterDownloaded and getDownloadedChapter return correct values', () async {
      expect(downloadService.isChapterDownloaded('m-1', 'ch-1'), isFalse);
      expect(downloadService.getDownloadedChapter('m-1', 'ch-1'), isNull);

      final downloaded = DownloadedChapter(
        chapterId: 'ch-1',
        mangaId: 'm-1',
        mangaTitle: 'Test Manga',
        chapterTitle: 'Chapter 1',
        chapterNumber: 1.0,
        pageCount: 1,
        pageFilePaths: ['/dummy/path/1.jpg'],
        sizeBytes: 1024,
        downloadedAt: DateTime.now(),
      );

      await downloadsBox.put('m-1_ch-1', downloaded.toMap());

      expect(downloadService.isChapterDownloaded('m-1', 'ch-1'), isTrue);
      final retrieved = downloadService.getDownloadedChapter('m-1', 'ch-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.chapterTitle, 'Chapter 1');
      expect(retrieved.mangaId, 'm-1');
    });

    test('getDownloadsGroupedByManga aggregates chapters properly', () async {
      final ch1 = DownloadedChapter(
        chapterId: 'ch-1',
        mangaId: 'm-1',
        mangaTitle: 'Manga One',
        chapterTitle: 'Ch 1',
        chapterNumber: 1.0,
        pageCount: 1,
        pageFilePaths: [],
        sizeBytes: 1000,
        downloadedAt: DateTime.now(),
      );
      final ch2 = DownloadedChapter(
        chapterId: 'ch-2',
        mangaId: 'm-1',
        mangaTitle: 'Manga One',
        chapterTitle: 'Ch 2',
        chapterNumber: 2.0,
        pageCount: 1,
        pageFilePaths: [],
        sizeBytes: 2000,
        downloadedAt: DateTime.now(),
      );
      final ch3 = DownloadedChapter(
        chapterId: 'ch-3',
        mangaId: 'm-2',
        mangaTitle: 'Manga Two',
        chapterTitle: 'Ch 1',
        chapterNumber: 1.0,
        pageCount: 1,
        pageFilePaths: [],
        sizeBytes: 1500,
        downloadedAt: DateTime.now(),
      );

      await downloadsBox.put('m-1_ch-1', ch1.toMap());
      await downloadsBox.put('m-1_ch-2', ch2.toMap());
      await downloadsBox.put('m-2_ch-3', ch3.toMap());

      final groups = downloadService.getDownloadsGroupedByManga();
      expect(groups.length, 2);

      final group1 = groups.firstWhere((g) => g.mangaId == 'm-1');
      expect(group1.chapterCount, 2);
      expect(group1.totalSizeBytes, 3000);
      expect(group1.mangaTitle, 'Manga One');

      final group2 = groups.firstWhere((g) => g.mangaId == 'm-2');
      expect(group2.chapterCount, 1);
      expect(group2.totalSizeBytes, 1500);

      expect(downloadService.getTotalDownloadedBytes(), 4500);
    });

    test('deleteDownloadedChapter removes files and box entry', () async {
      final downloadsDir = await fakeStorage.getDownloadsDirectory();
      final chapterDir = Directory('${downloadsDir.path}/m-1/ch-1');
      chapterDir.createSync(recursive: true);
      final testFile = File('${chapterDir.path}/p1.jpg');
      testFile.writeAsStringSync('dummy content');

      final ch = DownloadedChapter(
        chapterId: 'ch-1',
        mangaId: 'm-1',
        mangaTitle: 'Manga One',
        chapterTitle: 'Ch 1',
        chapterNumber: 1.0,
        pageCount: 1,
        pageFilePaths: [testFile.path],
        sizeBytes: 13,
        downloadedAt: DateTime.now(),
      );
      await downloadsBox.put('m-1_ch-1', ch.toMap());

      expect(testFile.existsSync(), isTrue);
      expect(downloadService.isChapterDownloaded('m-1', 'ch-1'), isTrue);

      await downloadService.deleteDownloadedChapter('m-1', 'ch-1');

      expect(downloadService.isChapterDownloaded('m-1', 'ch-1'), isFalse);
      expect(testFile.existsSync(), isFalse);
      expect(chapterDir.existsSync(), isFalse);
    });

    test('deleteMangaDownloads removes all chapters for that manga', () async {
      final downloadsDir = await fakeStorage.getDownloadsDirectory();
      final mangaDir = Directory('${downloadsDir.path}/m-1');
      mangaDir.createSync(recursive: true);
      Directory('${mangaDir.path}/ch-1').createSync();
      Directory('${mangaDir.path}/ch-2').createSync();

      final ch1 = DownloadedChapter(
        chapterId: 'ch-1',
        mangaId: 'm-1',
        mangaTitle: 'Manga One',
        chapterTitle: 'Ch 1',
        chapterNumber: 1.0,
        pageCount: 1,
        pageFilePaths: [],
        sizeBytes: 100,
        downloadedAt: DateTime.now(),
      );
      final ch2 = DownloadedChapter(
        chapterId: 'ch-2',
        mangaId: 'm-1',
        mangaTitle: 'Manga One',
        chapterTitle: 'Ch 2',
        chapterNumber: 2.0,
        pageCount: 1,
        pageFilePaths: [],
        sizeBytes: 200,
        downloadedAt: DateTime.now(),
      );
      await downloadsBox.put('m-1_ch-1', ch1.toMap());
      await downloadsBox.put('m-1_ch-2', ch2.toMap());

      await downloadService.deleteMangaDownloads('m-1');

      expect(downloadService.isChapterDownloaded('m-1', 'ch-1'), isFalse);
      expect(downloadService.isChapterDownloaded('m-1', 'ch-2'), isFalse);
      expect(mangaDir.existsSync(), isFalse);
    });

    test('downloadChapter queues task and cancelDownload marks canceled', () {
      final chapter = Chapter(
        id: 'ch-10',
        title: 'Chapter 10',
        chapterNumber: 10.0,
        date: DateTime(2026, 1, 1),
        totalPages: 20,
      );
      final manga = MangaDetail(
        id: 'm-1',
        malId: 101,
        title: 'Manga One',
        author: 'Author One',
        type: 'manga',
        status: 'ongoing',
        popularity: 10,
        members: 10,
        totalView: 100,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        chapters: [chapter],
      );

      downloadService.downloadChapter(manga, chapter);

      final task = downloadService.getTask('ch-10');
      expect(task, isNotNull);
      expect(task!.chapter.id, 'ch-10');
      expect(task.chapter.chapterNumber, 10.0);

      // Cancel task
      downloadService.cancelDownload('ch-10');
      final cancelled = downloadService.getTask('ch-10');
      expect(cancelled?.status, DownloadStatus.canceled);
    });
  });
}
