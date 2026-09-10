import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/chapter_page.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';
import 'package:my_manga_reader/features/reader/models/reader_content.dart';

void main() {
  group('ReaderContent Model Tests', () {
    final sampleChapters = [
      Chapter(
        id: 'ch-3',
        title: 'Chapter 3',
        chapterNumber: 3.0,
        date: DateTime(2025, 1, 3),
      ),
      Chapter(
        id: 'ch-2',
        title: 'Chapter 2',
        chapterNumber: 2.0,
        date: DateTime(2025, 1, 2),
      ),
      Chapter(
        id: 'ch-1',
        title: 'Chapter 1',
        chapterNumber: 1.0,
        date: DateTime(2025, 1, 1),
      ),
    ];

    test('constructor populates pageUrls and pageAspectRatios from pages', () {
      final content = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Manga Title',
        currentChapterNumber: 1.0,
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        allChapters: sampleChapters,
        pages: const [
          ChapterPage(url: 'https://img.com/1.jpg', width: 1000, height: 2000),
          ChapterPage(url: 'https://img.com/2.jpg', width: 800, height: 1200),
          ChapterPage(url: 'https://img.com/3.jpg'), // no dimensions
        ],
      );

      expect(content.totalPages, 3);
      expect(content.pageUrls, [
        'https://img.com/1.jpg',
        'https://img.com/2.jpg',
        'https://img.com/3.jpg',
      ]);
      expect(content.pageAspectRatios?[0], 2.0);
      expect(content.pageAspectRatios?[1], 1.5);
      expect(content.pageAspectRatios?.containsKey(2), isFalse);
    });

    test('constructor falls back to pageUrls when pages is null', () {
      final content = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Manga Title',
        currentChapterNumber: 1.0,
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        allChapters: sampleChapters,
        pageUrls: ['https://img.com/a.jpg', 'https://img.com/b.jpg'],
      );

      expect(content.totalPages, 2);
      expect(content.pageUrls.length, 2);
      expect(content.pages, isNull);
      expect(content.pageAspectRatios, isNull);
    });

    test('getChapterIndex finds by ID and falls back to chapterNumber', () {
      final content = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Manga Title',
        currentChapterNumber: 2.0,
        chapterId: 'ch-2',
        chapterTitle: 'Chapter 2',
        allChapters: sampleChapters,
      );

      // By ID
      expect(content.getChapterIndex('ch-3'), 0);
      expect(content.getChapterIndex('ch-2'), 1);
      expect(content.getChapterIndex('ch-1'), 2);

      // Fallback by chapter number
      expect(content.getChapterIndex('non-existent-id', 3.0), 0);
      expect(content.getChapterIndex('non-existent-id', 1.0), 2);

      // Not found
      expect(content.getChapterIndex('unknown-id', 99.0), -1);
    });

    test('getNextChapter and getPreviousChapter navigate correctly', () {
      final content = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Manga Title',
        currentChapterNumber: 2.0,
        chapterId: 'ch-2',
        chapterTitle: 'Chapter 2',
        allChapters: sampleChapters,
      );

      // Current is Chapter 2 (index 1)
      final next = content.getNextChapter('ch-2');
      expect(next?.id, 'ch-3');
      expect(content.hasNextChapter('ch-2'), isTrue);

      final prev = content.getPreviousChapter('ch-2');
      expect(prev?.id, 'ch-1');
      expect(content.hasPreviousChapter('ch-2'), isTrue);

      // Edge case: Top-most chapter (ch-3, index 0) has no next chapter
      expect(content.getNextChapter('ch-3'), isNull);
      expect(content.hasNextChapter('ch-3'), isFalse);
      expect(content.getPreviousChapter('ch-3')?.id, 'ch-2');

      // Edge case: Bottom-most chapter (ch-1, index 2) has no previous chapter
      expect(content.getPreviousChapter('ch-1'), isNull);
      expect(content.hasPreviousChapter('ch-1'), isFalse);
      expect(content.getNextChapter('ch-1')?.id, 'ch-2');
    });

    test('fromMap and toMap serialize and deserialize accurately', () {
      final original = ReaderContent(
        mangaId: 'manga-123',
        mangaTitle: 'Test Manga',
        currentChapterNumber: 2.0,
        chapterId: 'ch-2',
        chapterTitle: 'Chapter 2: The Journey',
        allChapters: sampleChapters,
        pages: const [
          ChapterPage(url: 'https://img.com/p1.jpg', width: 500, height: 1000),
        ],
        currentPage: 5,
        httpHeaders: {'Referer': 'https://provider.com'},
      );

      final map = original.toMap();
      expect(map['mangaId'], 'manga-123');
      expect(map['currentPage'], 5);
      expect(map['totalPages'], 1);
      expect(map['httpHeaders'], {'Referer': 'https://provider.com'});
      expect(map['pageAspectRatios'], {'0': 2.0});

      final parsed = ReaderContent.fromMap(map);
      expect(parsed.mangaId, original.mangaId);
      expect(parsed.chapterId, original.chapterId);
      expect(parsed.currentPage, original.currentPage);
      expect(parsed.pageUrls, original.pageUrls);
      expect(parsed.pageAspectRatios?[0], 2.0);
      expect(parsed.httpHeaders, {'Referer': 'https://provider.com'});
    });

    test('copyWith properly updates specific fields', () {
      final content = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Manga Title',
        currentChapterNumber: 1.0,
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        allChapters: sampleChapters,
        currentPage: 1,
      );

      final updated = content.copyWith(
        currentPage: 42,
        chapterTitle: 'Updated Title',
      );

      expect(updated.currentPage, 42);
      expect(updated.chapterTitle, 'Updated Title');
      expect(updated.chapterId, 'ch-1');
      expect(updated.mangaId, 'm1');
    });
  });
}
