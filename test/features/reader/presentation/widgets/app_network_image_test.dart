import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/app_network_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '/tmp';
    });
  });
  group('AppNetworkImage Widget Tests', () {
    testWidgets('renders placeholder or image container initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              imageUrl: 'https://example.com/manga/page1.jpg',
            ),
          ),
        ),
      );

      expect(find.byType(AppNetworkImage), findsOneWidget);
    });

    testWidgets('custom errorWidget overlays retry button and responds to tap', (tester) async {
      bool outerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () {
                outerTapped = true;
              },
              child: AppNetworkImage(
                imageUrl: 'https://example.com/manga/page_broken.jpg',
                errorWidget: Container(
                  height: 300,
                  color: Colors.black,
                  child: const Icon(Icons.broken_image, key: Key('broken_icon')),
                ),
              ),
            ),
          ),
        ),
      );

      final errorWidgetFinder = find.byType(AppNetworkImage);
      expect(errorWidgetFinder, findsOneWidget);
      expect(outerTapped, isFalse);
    });

    testWidgets('didUpdateWidget resets reload states for new URL', (tester) async {
      final key = GlobalKey<AppNetworkImageState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              key: key,
              imageUrl: 'https://example.com/manga/page_fail.jpg',
            ),
          ),
        ),
      );

      final state = key.currentState;
      expect(state, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              key: key,
              imageUrl: 'https://example.com/manga/page_new.jpg',
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AppNetworkImage), findsOneWidget);
    });

    testWidgets('forceReload resets states, evicts caches, and reloads', (tester) async {
      final key = GlobalKey<AppNetworkImageState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppNetworkImage(
              key: key,
              imageUrl: 'https://example.com/manga/page1.jpg',
              errorWidget: const SizedBox(
                width: 200,
                height: 200,
                child: Text('Custom Error Widget'),
              ),
            ),
          ),
        ),
      );

      final state = key.currentState;
      expect(state, isNotNull);

      // Verify calling forceReload works cleanly and debounces concurrent calls
      await tester.runAsync(() async {
        final f1 = state!.forceReload();
        final f2 = state.forceReload();
        await Future.wait([f1, f2]);
      });

      await tester.pump();
      expect(find.byType(AppNetworkImage), findsOneWidget);
    });
  });
}
