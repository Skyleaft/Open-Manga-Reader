import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/utils/url_utils.dart';

void main() {
  group('UrlUtils Tests', () {
    test('isLocalFilePath identifies network vs local paths accurately', () {
      expect(UrlUtils.isLocalFilePath('http://example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('https://example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('//cdn.example.com/image.jpg'), isFalse);
      expect(UrlUtils.isLocalFilePath('   https://example.com/image.jpg '), isFalse);

      expect(UrlUtils.isLocalFilePath(r'D:\Documents\downloads\ch1\001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('D:/Documents/downloads/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('D:%5CDocuments/downloads/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('/data/user/0/cache/image.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath('file:///D:/Documents/ch1/001.webp'), isTrue);
      expect(UrlUtils.isLocalFilePath(''), isFalse);
    });

    test('normalizeLocalFilePath unescapes %5C and %20 on Windows paths', () {
      const encodedWindowsPath =
          'D:%5CDocuments/downloads/01a02058-35ce-7471-90ea-63d960ce9fc6/01a02058-35d5-75bc-9637-3369bd2153f5/006.webp';

      final normalized = UrlUtils.normalizeLocalFilePath(encodedWindowsPath);

      if (Platform.isWindows) {
        expect(
          normalized,
          r'D:\Documents\downloads\01a02058-35ce-7471-90ea-63d960ce9fc6\01a02058-35d5-75bc-9637-3369bd2153f5\006.webp',
        );
      } else {
        expect(normalized, contains(r'D:\Documents/downloads'));
      }
    });

    test('sanitizeImageUrl does NOT URL-encode backslashes for local files', () {
      const windowsLocalPath = r'D:\Documents\downloads\ch1\001.webp';
      final sanitized = UrlUtils.sanitizeImageUrl(windowsLocalPath);

      expect(sanitized.contains('%5C'), isFalse);
      expect(sanitized.contains('%5c'), isFalse);

      // Network URLs should still be encoded
      const networkUrl = 'https://example.com/folder name/image.jpg';
      final sanitizedNetwork = UrlUtils.sanitizeImageUrl(networkUrl);
      expect(sanitizedNetwork, 'https://example.com/folder%20name/image.jpg');
    });
  });
}
