import '../../manga_detail/models/manga_detail.dart';
import '../../history/models/progression.dart';
import '../../../core/models/chapter_page.dart';

class ReaderContent {
  final String mangaId;
  final String mangaTitle;
  final double currentChapterNumber;
  final List<Chapter> allChapters;
  final String chapterId;
  final String chapterTitle;
  final List<String> pageUrls;
  final List<ChapterPage>? pages;
  final int currentPage;
  final int totalPages;
  final MangaProgression? progression;
  final Map<String, String>? httpHeaders;
  final Map<int, double>? pageAspectRatios;

  ReaderContent({
    required this.mangaId,
    required this.mangaTitle,
    required this.currentChapterNumber,
    required this.chapterId,
    required this.allChapters,
    required this.chapterTitle,
    List<String>? pageUrls,
    this.pages,
    this.currentPage = 1,
    this.progression,
    this.httpHeaders,
    Map<int, double>? pageAspectRatios,
  })  : pageUrls = pageUrls ?? pages?.map((p) => p.url).toList() ?? [],
        pageAspectRatios = pageAspectRatios ??
            (pages != null
                ? {
                    for (int i = 0; i < pages.length; i++)
                      if (pages[i].aspectRatio != null) i: pages[i].aspectRatio!,
                  }
                : null),
        totalPages =
            (pageUrls ?? pages?.map((p) => p.url).toList() ?? []).length;

  ReaderContent copyWith({
    String? mangaId,
    String? mangaTitle,
    double? currentChapterNumber,
    List<Chapter>? allChapters,
    String? chapterId,
    String? chapterTitle,
    List<String>? pageUrls,
    List<ChapterPage>? pages,
    int? currentPage,
    MangaProgression? progression,
    Map<String, String>? httpHeaders,
    Map<int, double>? pageAspectRatios,
  }) {
    return ReaderContent(
      mangaId: mangaId ?? this.mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      currentChapterNumber: currentChapterNumber ?? this.currentChapterNumber,
      allChapters: allChapters ?? this.allChapters,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      pageUrls: pageUrls ?? (pages == null ? this.pageUrls : null),
      pages: pages ?? this.pages,
      currentPage: currentPage ?? this.currentPage,
      progression: progression ?? this.progression,
      httpHeaders: httpHeaders ?? this.httpHeaders,
      pageAspectRatios: pageAspectRatios ?? this.pageAspectRatios,
    );
  }

  int getChapterIndex(String chapterId, [double? chapterNumber]) {
    int idx = allChapters.indexWhere((c) => c.id == chapterId);
    if (idx != -1) return idx;
    if (chapterNumber != null) {
      idx = allChapters.indexWhere((c) => c.chapterNumber == chapterNumber);
      if (idx != -1) return idx;
    }
    return -1;
  }

  Chapter? getNextChapter(String chapterId, [double? chapterNumber]) {
    final idx = getChapterIndex(chapterId, chapterNumber);
    if (idx > 0 && idx < allChapters.length) {
      return allChapters[idx - 1];
    }
    return null;
  }

  Chapter? getPreviousChapter(String chapterId, [double? chapterNumber]) {
    final idx = getChapterIndex(chapterId, chapterNumber);
    if (idx >= 0 && idx < allChapters.length - 1) {
      return allChapters[idx + 1];
    }
    return null;
  }

  bool hasNextChapter(String chapterId, [double? chapterNumber]) {
    return getNextChapter(chapterId, chapterNumber) != null;
  }

  bool hasPreviousChapter(String chapterId, [double? chapterNumber]) {
    return getPreviousChapter(chapterId, chapterNumber) != null;
  }

  factory ReaderContent.fromMap(Map<String, dynamic> map) {
    final rawPages =
        map['pages'] as List<dynamic>? ?? map['pageUrls'] as List<dynamic>?;
    final List<ChapterPage> parsedPages = [];
    final List<String> parsedUrls = [];
    final Map<int, double> parsedRatios = {};

    if (rawPages != null) {
      for (int i = 0; i < rawPages.length; i++) {
        final item = rawPages[i];
        final page = ChapterPage.fromDynamic(item);
        parsedPages.add(page);
        parsedUrls.add(page.url);
        if (page.aspectRatio != null) {
          parsedRatios[i] = page.aspectRatio!;
        }
      }
    }

    if (map['pageAspectRatios'] is Map) {
      (map['pageAspectRatios'] as Map).forEach((key, value) {
        final k = key is int ? key : int.tryParse(key.toString());
        final v = (value as num?)?.toDouble();
        if (k != null && v != null) {
          parsedRatios[k] = v;
        }
      });
    }

    Map<String, String>? headers;
    if (map['httpHeaders'] is Map) {
      headers = (map['httpHeaders'] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (map['headers'] is Map) {
      headers = (map['headers'] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }

    return ReaderContent(
      mangaId: map['mangaId'] as String? ?? '',
      mangaTitle: map['mangaTitle'] as String? ?? '',
      currentChapterNumber:
          (map['currentChapterNumber'] as num? ?? map['number'] as num? ?? 0)
              .toDouble(),
      chapterId: map['chapterId'] as String? ?? map['id'] as String? ?? "",
      allChapters: (map['allChapters'] as List<dynamic>?)
              ?.map((e) => Chapter.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      chapterTitle:
          map['chapterTitle'] as String? ?? map['title'] as String? ?? '',
      pageUrls: parsedUrls,
      pages: parsedPages.isNotEmpty ? parsedPages : null,
      currentPage: map['currentPage'] as int? ?? 1,
      httpHeaders: headers,
      pageAspectRatios: parsedRatios.isNotEmpty ? parsedRatios : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'mangaTitle': mangaTitle,
      'currentChapterNumber': currentChapterNumber,
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'pageUrls': pageUrls,
      if (pages != null) 'pages': pages!.map((p) => p.toMap()).toList(),
      'currentPage': currentPage,
      'totalPages': totalPages,
      'httpHeaders': httpHeaders,
      if (pageAspectRatios != null)
        'pageAspectRatios': pageAspectRatios!.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
    };
  }
}

