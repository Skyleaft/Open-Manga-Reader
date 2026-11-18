import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flutter 3.50 Scrolling and Slivers Feature Tests', () {
    testWidgets('SliverClipRRect renders with clipOverlap preserveShape without errors', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scrollController,
              slivers: [
                const SliverAppBar(
                  pinned: true,
                  expandedHeight: 120,
                  flexibleSpace: FlexibleSpaceBar(title: Text('Pinned Header')),
                ),
                SliverClipRRect(
                  clipOverlap: ClipOverlapBehavior.preserveShape,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Container(
                        height: 80,
                        color: index.isEven ? Colors.blue : Colors.red,
                        child: Text('Item $index'),
                      ),
                      childCount: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SliverClipRRect), findsOneWidget);
      expect(find.text('Pinned Header'), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);

      // Scroll down so items overlap pinned header
      await tester.drag(find.text('Item 0'), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(find.byType(SliverClipRRect), findsOneWidget);
    });

    testWidgets('ListView.separated with itemExtentBuilder sizes items and separators lazily', (tester) async {
      final builtIndices = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: ListView.separated(
                itemCount: 100,
                itemExtentBuilder: (index, dimensions) {
                  // even index = item (height 50.0), odd index = separator (height 10.0)
                  return index.isEven ? 50.0 : 10.0;
                },
                separatorBuilder: (context, index) {
                  return const Divider(height: 10);
                },
                itemBuilder: (context, index) {
                  builtIndices.add(index);
                  return SizedBox(
                    height: 50,
                    child: Text('Row $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Only a subset of rows should be built (lazy evaluation)
      expect(find.text('Row 0'), findsOneWidget);
      expect(find.text('Row 1'), findsOneWidget);
      // Row 80 must NOT have been built (thanks to itemExtentBuilder lazy layout)
      expect(find.text('Row 80'), findsNothing);
      expect(builtIndices.contains(80), isFalse);
    });
  });
}
