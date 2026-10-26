import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_shortcuts_dialog.dart';

void main() {
  group('ReaderShortcutsDialog Widget Tests', () {
    testWidgets('renders all keyboard shortcut sections and keys', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReaderShortcutsDialog(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('NAVIGATION & SCROLLING'), findsOneWidget);
      expect(find.text('CHAPTER CONTROL'), findsOneWidget);
      expect(find.text('READER FEATURES'), findsOneWidget);

      expect(find.text('Scroll Webtoon page'), findsOneWidget);
      expect(find.text('Previous Chapter'), findsOneWidget);
      expect(find.text('Next Chapter'), findsOneWidget);
      expect(find.text('Toggle Auto-scroll'), findsOneWidget);

      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('pops dialog when Got it or Close button is pressed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => ReaderShortcutsDialog.show(context),
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });
  });
}
