class ChapterPage {
  final String url;
  final int width;
  final int height;
  final String? alternateUrl;
  final bool isFallback;

  const ChapterPage({
    required this.url,
    this.width = 0,
    this.height = 0,
    this.alternateUrl,
    this.isFallback = false,
  });

  /// The aspect ratio (height / width) of the page image, or null if dimensions are unknown.
  double? get aspectRatio => (width > 0 && height > 0) ? (height / width) : null;

  factory ChapterPage.fromDynamic(dynamic item) {
    if (item is ChapterPage) return item;
    if (item is String) {
      return ChapterPage(url: item);
    }
    if (item is Map<String, dynamic>) {
      return ChapterPage.fromMap(item);
    }
    if (item is Map) {
      return ChapterPage.fromMap(Map<String, dynamic>.from(item));
    }
    return ChapterPage(url: item?.toString() ?? '');
  }

  factory ChapterPage.fromMap(Map<String, dynamic> map) {
    final rawWidth = map['width'];
    final rawHeight = map['height'];
    final int width = (rawWidth is num)
        ? rawWidth.toInt()
        : int.tryParse(rawWidth?.toString() ?? '') ?? 0;
    final int height = (rawHeight is num)
        ? rawHeight.toInt()
        : int.tryParse(rawHeight?.toString() ?? '') ?? 0;

    return ChapterPage(
      url: map['url'] as String? ?? '',
      width: width,
      height: height,
      alternateUrl: map['alternateUrl'] as String?,
      isFallback: map['isFallback'] as bool? ?? false,
    );
  }

  ChapterPage copyWith({
    String? url,
    int? width,
    int? height,
    String? alternateUrl,
    bool? isFallback,
  }) {
    return ChapterPage(
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
      alternateUrl: alternateUrl ?? this.alternateUrl,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'width': width,
      'height': height,
      if (alternateUrl != null) 'alternateUrl': alternateUrl,
      'isFallback': isFallback,
    };
  }

  @override
  String toString() =>
      'ChapterPage(url: $url, width: $width, height: $height, alternateUrl: $alternateUrl, isFallback: $isFallback)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChapterPage &&
        other.url == url &&
        other.width == width &&
        other.height == height &&
        other.alternateUrl == alternateUrl &&
        other.isFallback == isFallback;
  }

  @override
  int get hashCode => Object.hash(url, width, height, alternateUrl, isFallback);
}
