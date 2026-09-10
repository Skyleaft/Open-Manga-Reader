import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_content.dart';

void main() {
  group('ReaderContentWidget Tests', () {
    late ScrollController scrollController;
    late PageController pageController;
    late TransformationController transformationController;

    setUp(() {
      scrollController = ScrollController();
      pageController = PageController();
      transformationController = TransformationController();
    });

    tearDown(() {
      scrollController.dispose();
      pageController.dispose();
      transformationController.dispose();
    });

    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ReaderContentWidget(
                  pageUrls: const ['https://img.com/1.jpg'],
                  isLoading: true,
                  showUI: true,
                  transformationController: transformationController,
                  scrollController: scrollController,
                  pageController: pageController,
                  isWebtoonMode: true,
                  onPageChanged: (_) {},
                  onTap: () {},
                  onDoubleTapDown: (_) {},
                  onDoubleTap: () {},
                  onToggleUI: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('webtoon mode binds getPageKey to each page item', (tester) async {
      final Map<int, GlobalKey> customKeys = {
        0: GlobalKey(debugLabel: 'test_page_0'),
        1: GlobalKey(debugLabel: 'test_page_1'),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ReaderContentWidget(
                  chapterId: 'ch-test',
                  pageUrls: const ['https://img.com/1.jpg', 'https://img.com/2.jpg'],
                  isLoading: false,
                  showUI: true,
                  transformationController: transformationController,
                  scrollController: scrollController,
                  pageController: pageController,
                  isWebtoonMode: true,
                  getPageKey: (index) => customKeys[index]!,
                  defaultAspectRatio: 2.0,
                  onPageChanged: (_) {},
                  onTap: () {},
                  onDoubleTapDown: (_) {},
                  onDoubleTap: () {},
                  onToggleUI: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify customKeys are present in the widget tree
      expect(find.byKey(customKeys[0]!), findsOneWidget);
      expect(customKeys[0]!.currentContext, isNotNull);
    });

    testWidgets('paged mode renders PageView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ReaderContentWidget(
                  chapterId: 'ch-test',
                  pageUrls: const ['https://img.com/1.jpg', 'https://img.com/2.jpg'],
                  isLoading: false,
                  showUI: true,
                  transformationController: transformationController,
                  scrollController: scrollController,
                  pageController: pageController,
                  isWebtoonMode: false,
                  isRtlMode: false,
                  onPageChanged: (_) {},
                  onTap: () {},
                  onDoubleTapDown: (_) {},
                  onDoubleTap: () {},
                  onToggleUI: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
