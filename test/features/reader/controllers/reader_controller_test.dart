import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/chapter_page.dart';
import 'package:my_manga_reader/features/manga_detail/models/manga_detail.dart';
import 'package:my_manga_reader/features/reader/controllers/reader_controller.dart';
import 'package:my_manga_reader/features/reader/models/reader_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderController Tests', () {
    final sampleChapters = [
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

    late ReaderContent sampleContent;

    setUp(() {
      sampleContent = ReaderContent(
        mangaId: 'm1',
        mangaTitle: 'Test Manga',
        currentChapterNumber: 1.0,
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        allChapters: sampleChapters,
        currentPage: 2,
        pages: const [
          ChapterPage(url: 'https://img.com/1.jpg', width: 1000, height: 1500),
          ChapterPage(url: 'https://img.com/2.jpg', width: 1000, height: 1400),
          ChapterPage(url: 'https://img.com/3.jpg', width: 1000, height: 1600),
        ],
      );
    });

    test('initializes state correctly from ReaderContent', () {
      final controller = ReaderController(content: sampleContent);

      expect(controller.content, sampleContent);
      expect(controller.chapterId, 'ch-1');
      expect(controller.currentChapterNumber, 1.0);
      expect(controller.pageUrls.length, 3);
      expect(controller.currentPage, 2);
      expect(controller.progress, 0.5);
      expect(controller.showUI, isTrue);
      expect(controller.isWebtoonMode, isTrue);
      expect(controller.isRtlMode, isFalse);
      expect(controller.isAutoScrolling, isFalse);

      controller.dispose();
    });

    test('UI and display mode toggles notify listeners', () {
      final controller = ReaderController(content: sampleContent);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.toggleUI();
      expect(controller.showUI, isFalse);
      expect(notifyCount, 1);

      controller.setShowUI(true);
      expect(controller.showUI, isTrue);
      expect(notifyCount, 2);

      controller.setWebtoonMode(false);
      expect(controller.isWebtoonMode, isFalse);
      expect(notifyCount, 3);

      controller.setRtlMode(true);
      expect(controller.isRtlMode, isTrue);
      expect(notifyCount, 4);

      controller.setHideMiniProgressBar(true);
      expect(controller.hideMiniProgressBar, isTrue);
      expect(notifyCount, 5);

      controller.dispose();
    });

    test('auto-scroll toggles and speed updates', () {
      final controller = ReaderController(content: sampleContent);
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.toggleAutoScroll();
      expect(controller.isAutoScrolling, isTrue);
      expect(controller.showUI, isFalse); // auto-scroll hides UI automatically

      controller.setAutoScrollSpeed(2.0);
      expect(controller.autoScrollSpeed, 2.0);

      controller.setAutoScrolling(false);
      expect(controller.isAutoScrolling, isFalse);

      controller.dispose();
    });

    test('updatePageAndProgress updates ValueNotifiers with isolated re-render', () {
      final controller = ReaderController(content: sampleContent);
      bool pageNotified = false;
      bool progressNotified = false;
      bool controllerNotified = false;

      controller.currentPageNotifier.addListener(() => pageNotified = true);
      controller.progressNotifier.addListener(() => progressNotified = true);
      controller.addListener(() => controllerNotified = true);

      // Default: does not notify global controller to prevent full-tree rebuild
      controller.updatePageAndProgress(3, 1.0);
      expect(controller.currentPage, 3);
      expect(controller.progress, 1.0);
      expect(pageNotified, isTrue);
      expect(progressNotified, isTrue);
      expect(controllerNotified, isFalse);

      // With notifyController: true
      controller.updatePageAndProgress(1, 0.0, notifyController: true);
      expect(controller.currentPage, 1);
      expect(controller.progress, 0.0);
      expect(controllerNotified, isTrue);

      controller.dispose();
    });

    test('overscroll notifier updates without notifying full controller', () {
      final controller = ReaderController(content: sampleContent);
      bool overscrollNotified = false;
      bool controllerNotified = false;

      controller.accumulatedBottomOverscrollNotifier
          .addListener(() => overscrollNotified = true);
      controller.addListener(() => controllerNotified = true);

      controller.addAccumulatedBottomOverscroll(50.0);
      expect(controller.accumulatedBottomOverscroll, 50.0);
      expect(overscrollNotified, isTrue);
      expect(controllerNotified, isFalse);

      controller.setAccumulatedBottomOverscroll(0.0);
      expect(controller.accumulatedBottomOverscroll, 0.0);

      controller.dispose();
    });

    test('clearError clears error message and notifies listeners', () {
      final controller = ReaderController(content: sampleContent);
      expect(controller.errorMessage, isNull);

      controller.clearError();
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('calculateAverageRatio and calculateEstimatedOffset calculate correctly', () {
      final controller = ReaderController(content: sampleContent);

      final avg = controller.calculateAverageRatio();
      expect(avg, closeTo(1.5, 0.01));

      final offset = controller.calculateEstimatedOffset(2, 400.0);
      expect(offset, greaterThan(0.0));

      controller.dispose();
    });

    test('changeChapter triggers onChapterNotFound when chapter does not exist', () async {
      final controller = ReaderController(content: sampleContent);
      bool notFoundCalled = false;

      // Going backward from Chapter 1 (the first chapter)
      await controller.changeChapter(
        next: false,
        onChapterNotFound: () {
          notFoundCalled = true;
        },
      );

      expect(notFoundCalled, isTrue);
      controller.dispose();
    });
  });
}
