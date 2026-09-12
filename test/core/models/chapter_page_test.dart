import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/models/chapter_page.dart';

void main() {
  group('ChapterPage Model Tests', () {
    test('creates ChapterPage with default dimensions', () {
      const page = ChapterPage(url: 'https://example.com/page1.jpg');

      expect(page.url, 'https://example.com/page1.jpg');
      expect(page.width, 0);
      expect(page.height, 0);
      expect(page.aspectRatio, isNull);
      expect(page.alternateUrl, isNull);
    });

    test('calculates aspectRatio when width and height > 0', () {
      const page = ChapterPage(
        url: 'https://example.com/page1.jpg',
        width: 1000,
        height: 2500,
      );

      expect(page.aspectRatio, 2.5);
    });

    test('aspectRatio returns null when width or height is 0', () {
      const pageWithZeroWidth = ChapterPage(
        url: 'https://example.com/page1.jpg',
        width: 0,
        height: 1000,
      );
      expect(pageWithZeroWidth.aspectRatio, isNull);

      const pageWithZeroHeight = ChapterPage(
        url: 'https://example.com/page1.jpg',
        width: 1000,
        height: 0,
      );
      expect(pageWithZeroHeight.aspectRatio, isNull);
    });

    test('fromDynamic handles string, map, and ChapterPage instance', () {
      // String
      final fromString = ChapterPage.fromDynamic('https://example.com/1.jpg');
      expect(fromString.url, 'https://example.com/1.jpg');
      expect(fromString.width, 0);

      // Map<String, dynamic>
      final fromMap = ChapterPage.fromDynamic({
        'url': 'https://example.com/2.jpg',
        'width': 800,
        'height': 1200,
        'alternateUrl': 'https://mirror.com/2.jpg',
      });
      expect(fromMap.url, 'https://example.com/2.jpg');
      expect(fromMap.width, 800);
      expect(fromMap.height, 1200);
      expect(fromMap.aspectRatio, 1.5);
      expect(fromMap.alternateUrl, 'https://mirror.com/2.jpg');

      // Untyped Map
      final fromUntypedMap = ChapterPage.fromDynamic(<dynamic, dynamic>{
        'url': 'https://example.com/3.jpg',
        'width': '500',
        'height': '1000',
      });
      expect(fromUntypedMap.url, 'https://example.com/3.jpg');
      expect(fromUntypedMap.width, 500);
      expect(fromUntypedMap.height, 1000);

      // ChapterPage object identity
      final original = const ChapterPage(url: 'https://example.com/4.jpg');
      final fromObj = ChapterPage.fromDynamic(original);
      expect(identical(original, fromObj), isTrue);

      // null or unknown
      final fromNull = ChapterPage.fromDynamic(null);
      expect(fromNull.url, '');
    });

    test('toMap and fromMap serialize and deserialize correctly', () {
      const original = ChapterPage(
        url: 'https://example.com/p.jpg',
        width: 1080,
        height: 1920,
        alternateUrl: 'https://alt.com/p.jpg',
        isFallback: true,
      );

      final map = original.toMap();
      expect(map['url'], 'https://example.com/p.jpg');
      expect(map['width'], 1080);
      expect(map['height'], 1920);
      expect(map['alternateUrl'], 'https://alt.com/p.jpg');
      expect(map['isFallback'], isTrue);

      final deserialized = ChapterPage.fromMap(map);
      expect(deserialized, equals(original));
      expect(deserialized.hashCode, equals(original.hashCode));
      expect(deserialized.isFallback, isTrue);
    });

    test('copyWith produces updated clone', () {
      const page = ChapterPage(
        url: 'https://example.com/1.jpg',
        width: 100,
        height: 200,
      );

      final updated = page.copyWith(
        height: 300,
        alternateUrl: 'https://alt.com',
        isFallback: true,
      );
      expect(updated.url, 'https://example.com/1.jpg');
      expect(updated.width, 100);
      expect(updated.height, 300);
      expect(updated.alternateUrl, 'https://alt.com');
      expect(updated.isFallback, isTrue);
    });
  });
}
