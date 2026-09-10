import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_header.dart';

void main() {
  group('ReaderHeader Widget Tests', () {
    testWidgets('renders manga title and chapter title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Solo Leveling',
              chapterTitle: 'Chapter 179',
              onBack: () {},
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Solo Leveling'), findsOneWidget);
      expect(find.text('Chapter 179'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('triggers onBack when back button is pressed', (tester) async {
      bool backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Tower of God',
              chapterTitle: 'Chapter 100',
              onBack: () => backPressed = true,
              onSettings: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backPressed, isTrue);
    });

    testWidgets('triggers onSettings when settings button is pressed', (tester) async {
      bool settingsPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Omniscient Reader',
              chapterTitle: 'Chapter 50',
              onBack: () {},
              onSettings: () => settingsPressed = true,
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      expect(settingsPressed, isTrue);
    });

    testWidgets('triggers onChapterListTap when chapter info is clicked', (tester) async {
      bool chapterListTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'The Beginning After The End',
              chapterTitle: 'Chapter 120',
              onBack: () {},
              onSettings: () {},
              onChapterListTap: () => chapterListTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('The Beginning After The End'));
      expect(chapterListTapped, isTrue);
    });

    testWidgets('triggers onToggleFullscreen and shows correct icon', (tester) async {
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Nano Machine',
              chapterTitle: 'Chapter 10',
              onBack: () {},
              onSettings: () {},
              isFullscreen: false,
              onToggleFullscreen: () => fullscreenToggled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      expect(fullscreenToggled, isTrue);

      // Re-render with isFullscreen: true
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderHeader(
              mangaTitle: 'Nano Machine',
              chapterTitle: 'Chapter 10',
              onBack: () {},
              onSettings: () {},
              isFullscreen: true,
              onToggleFullscreen: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
    });
  });
}
