import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_bottom_bar.dart';

void main() {
  group('ReaderBottomBar Widget Tests', () {
    testWidgets('renders page indicator and progress percentage in LTR mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBottomBar(
              progress: 0.5,
              currentPage: 5,
              totalPages: 10,
              isSliderScrolling: false,
              isRtlMode: false,
              onProgressChanged: (_) {},
              onProgressChangeStart: (_) {},
              onProgressChangeEnd: (_) {},
              onNextChapter: () {},
              onPreviousChapter: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('PAGE 5 OF 10  •  50%'), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    });

    testWidgets('triggers navigation callbacks in LTR mode', (tester) async {
      bool prevCalled = false;
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBottomBar(
              progress: 0.2,
              currentPage: 2,
              totalPages: 10,
              isSliderScrolling: false,
              isRtlMode: false,
              onProgressChanged: (_) {},
              onProgressChangeStart: (_) {},
              onProgressChangeEnd: (_) {},
              onPreviousChapter: () => prevCalled = true,
              onNextChapter: () => nextCalled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // In LTR, left button (skip_previous) triggers onPreviousChapter
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(prevCalled, isTrue);

      // In LTR, right button (skip_next) triggers onNextChapter
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(nextCalled, isTrue);
    });

    testWidgets('swaps navigation actions and shows (RTL) tag in RTL mode', (tester) async {
      bool prevCalled = false;
      bool nextCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderBottomBar(
              progress: 0.75,
              currentPage: 15,
              totalPages: 20,
              isSliderScrolling: false,
              isRtlMode: true,
              onProgressChanged: (_) {},
              onProgressChangeStart: (_) {},
              onProgressChangeEnd: (_) {},
              onPreviousChapter: () => prevCalled = true,
              onNextChapter: () => nextCalled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Check RTL indicator in text
      expect(find.text('PAGE 15 OF 20  •  75% (RTL)'), findsOneWidget);

      // In RTL mode, left button triggers next chapter
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(nextCalled, isTrue);
      expect(prevCalled, isFalse);

      // In RTL mode, right button triggers previous chapter
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(prevCalled, isTrue);
    });
  });
}
