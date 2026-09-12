import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/chapter_page.dart';
import 'package:my_manga_reader/core/models/manga_summary.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';

void main() {
  group('Chapter Model Contract Updates', () {
    test('fromMap correctly parses chapter with excluded pages and totalPages > 0', () {
      final jsonMap = {
        'id': 'chapter-uuid-1',
        'number': 12.5,
        'link': 'https://example.com/ch/12.5',
        'language': 'en',
        'chapterProvider': 'MangaProvider',
        'chapterProviderIcon': 'https://example.com/icon.png',
        'uploadDate': '2026-09-12T12:00:00Z',
        'totalView': 1500,
        'totalPages': 32,
        'brokenPageCount': 2,
        'pages': null,
      };

      final chapter = Chapter.fromMap(jsonMap);

      expect(chapter.id, 'chapter-uuid-1');
      expect(chapter.chapterNumber, 12.5);
      expect(chapter.pages, isEmpty);
      expect(chapter.totalPages, 32);
      expect(chapter.brokenPageCount, 2);
      expect(chapter.pageCount, 32);
      expect(chapter.isChapterAvailable, isTrue);
      expect(chapter.totalView, 1500);
      expect(chapter.language, 'en');
      expect(chapter.chapterProvider, 'MangaProvider');
    });

    test('fromMap marks chapter unavailable when pages are empty and totalPages is 0', () {
      final jsonMap = {
        'id': 'ch-empty',
        'number': 1,
        'totalPages': 0,
        'brokenPageCount': 0,
        'pages': [],
      };

      final chapter = Chapter.fromMap(jsonMap);

      expect(chapter.pages, isEmpty);
      expect(chapter.totalPages, 0);
      expect(chapter.pageCount, 0);
      expect(chapter.isChapterAvailable, isFalse);
    });

    test('fromMap handles pages array when provided and falls back totalPages to pages length', () {
      final jsonMap = {
        'id': 'ch-with-pages',
        'number': 2,
        'pages': [
          {'url': 'https://img.com/p1.jpg', 'width': 1000, 'height': 1500},
          {'url': 'https://img.com/p2.jpg', 'width': 1000, 'height': 1500},
        ],
      };

      final chapter = Chapter.fromMap(jsonMap);

      expect(chapter.pages.length, 2);
      expect(chapter.totalPages, 2);
      expect(chapter.pageCount, 2);
      expect(chapter.isChapterAvailable, isTrue);
      expect(chapter.pageUrls, ['https://img.com/p1.jpg', 'https://img.com/p2.jpg']);
    });

    test('toMap and fromMap serialize and deserialize totalPages and brokenPageCount accurately', () {
      final original = Chapter(
        id: 'round-trip-1',
        title: 'Chapter 5',
        chapterNumber: 5.0,
        date: DateTime.parse('2026-09-12T10:00:00Z'),
        isChapterAvailable: true,
        totalPages: 28,
        brokenPageCount: 1,
        pages: const [
          ChapterPage(url: 'https://test.com/1.jpg', width: 800, height: 1200),
        ],
      );

      final map = original.toMap();
      expect(map['totalPages'], 28);
      expect(map['brokenPageCount'], 1);

      final restored = Chapter.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.totalPages, original.totalPages);
      expect(restored.brokenPageCount, original.brokenPageCount);
      expect(restored.isChapterAvailable, isTrue);
      expect(restored.pageCount, 28);
    });

    test('copyWith updates totalPages and brokenPageCount', () {
      final chapter = Chapter(
        id: 'test-ch',
        title: 'Title',
        chapterNumber: 1.0,
        date: DateTime.now(),
        totalPages: 10,
        brokenPageCount: 0,
      );

      final updated = chapter.copyWith(
        totalPages: 25,
        brokenPageCount: 3,
      );

      expect(updated.totalPages, 25);
      expect(updated.brokenPageCount, 3);
      expect(updated.pageCount, 25);
    });
  });

  group('LatestChapterSummary Contract Updates', () {
    test('fromJson supports excluded pages with totalPages > 0', () {
      final json = {
        'id': 'latest-ch-id',
        'number': 99,
        'link': null,
        'uploadDate': '2026-09-12T08:00:00Z',
        'totalView': 5000,
        'totalPages': 45,
        'brokenPageCount': 0,
        'pages': null,
      };

      final summary = LatestChapterSummary.fromJson(json);

      expect(summary.id, 'latest-ch-id');
      expect(summary.number, 99.0);
      expect(summary.totalPages, 45);
      expect(summary.brokenPageCount, 0);
      expect(summary.pageCount, 45);
      expect(summary.isChapterAvailable, isTrue);

      final map = summary.toJson();
      expect(map['totalPages'], 45);
      expect(map['brokenPageCount'], 0);
    });
  });
}
