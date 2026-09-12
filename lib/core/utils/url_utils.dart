import 'dart:io';

class UrlUtils {
  /// Determines whether the given string represents a local file path.
  static bool isLocalFilePath(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('//')) {
      return false;
    }
    return true;
  }

  /// Normalizes a local file path (handles file:// URIs, URL-encoded %5C or %20,
  /// and Windows path separators).
  static String normalizeLocalFilePath(String path) {
    String clean = path.trim();
    if (clean.isEmpty) return clean;

    if (clean.startsWith('file://')) {
      try {
        clean = Uri.parse(clean).toFilePath(windows: Platform.isWindows);
      } catch (_) {
        clean = clean.replaceFirst('file://', '');
      }
    }

    // Unescape URL-encoded backslashes and spaces
    clean = clean.replaceAll('%5C', r'\').replaceAll('%5c', r'\');
    clean = clean.replaceAll('%20', ' ');

    if (clean.contains('%')) {
      try {
        clean = Uri.decodeComponent(clean);
      } catch (_) {}
    }

    if (Platform.isWindows) {
      // If it starts with /C: or /D: from URI parsing, strip leading slash
      if (RegExp(r'^\/[a-zA-Z]:').hasMatch(clean)) {
        clean = clean.substring(1);
      }
      clean = clean.replaceAll('/', r'\');
    }

    return clean;
  }

  static String sanitizeImageUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    // Never URL-encode local file paths
    if (isLocalFilePath(trimmed)) {
      return normalizeLocalFilePath(trimmed);
    }

    try {
      String decoded = trimmed;
      // Unwrap any potential double/triple encoding
      for (int i = 0; i < 3; i++) {
        if (decoded.contains('%20') || decoded.contains('%25')) {
          final next = Uri.decodeFull(decoded);
          if (next == decoded) break;
          decoded = next;
        } else {
          break;
        }
      }
      return Uri.encodeFull(decoded);
    } catch (_) {
      return Uri.encodeFull(trimmed);
    }
  }
}
