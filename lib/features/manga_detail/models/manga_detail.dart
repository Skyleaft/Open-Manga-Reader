import 'dart:convert';
import '../../../core/models/manga_summary.dart';
import '../../../core/models/chapter_page.dart';
import '../../history/models/progression.dart';

class MangaDetail {
  final String id;
  final int malId;
  final int? anilistId;
  final int? mangaUpdateId;
  final String title;
  final String author;
  final String type;
  final List<String>? genres;
  final List<String>? categories;
  final String? description;
  final String? imageUrl;
  final String? localImageUrl;
  final double? rating;
  final int popularity;
  final int members;
  final int totalView;
  final String? status;
  final DateTime? releaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? url;
  final List<Chapter> chapters;

  MangaDetail({
    required this.id,
    required this.malId,
    this.anilistId,
    this.mangaUpdateId,
    required this.title,
    required this.author,
    required this.type,
    this.genres,
    this.categories,
    this.description,
    this.imageUrl,
    this.localImageUrl,
    this.rating,
    required this.popularity,
    required this.members,
    required this.totalView,
    this.status,
    this.releaseDate,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    required this.chapters,
  });

  MangaDetail copyWith({
    String? id,
    int? malId,
    int? anilistId,
    int? mangaUpdateId,
    String? title,
    String? author,
    String? type,
    List<String>? genres,
    List<String>? categories,
    String? description,
    String? imageUrl,
    String? localImageUrl,
    double? rating,
    int? popularity,
    int? members,
    int? totalView,
    String? status,
    DateTime? releaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? url,
    List<Chapter>? chapters,
  }) {
    return MangaDetail(
      id: id ?? this.id,
      malId: malId ?? this.malId,
      anilistId: anilistId ?? this.anilistId,
      mangaUpdateId: mangaUpdateId ?? this.mangaUpdateId,
      title: title ?? this.title,
      author: author ?? this.author,
      type: type ?? this.type,
      genres: genres ?? this.genres,
      categories: categories ?? this.categories,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      localImageUrl: localImageUrl ?? this.localImageUrl,
      rating: rating ?? this.rating,
      popularity: popularity ?? this.popularity,
      members: members ?? this.members,
      totalView: totalView ?? this.totalView,
      status: status ?? this.status,
      releaseDate: releaseDate ?? this.releaseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      url: url ?? this.url,
      chapters: chapters ?? this.chapters,
    );
  }

  factory MangaDetail.fromMap(Map<String, dynamic> map) {
    return MangaDetail(
      id: map['id'] as String? ?? '',
      malId: map['malId'] as int? ?? map['malID'] as int? ?? 0,
      anilistId: map['anilistId'] as int?,
      mangaUpdateId: map['mangaUpdateId'] as int?,
      title: map['title'] as String? ?? 'Unknown Title',
      author: map['author'] as String? ?? 'Unknown Author',
      type: map['type'] as String? ?? 'Unknown Type',
      genres: (map['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      categories: (map['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      description: map['description'] as String? ?? 'No description available',
      imageUrl: map['imageUrl'] as String?,
      localImageUrl: map['localImageUrl'] as String?,
      rating: map['rating'] != null ? (map['rating'] as num).toDouble() : null,
      popularity: map['popularity'] as int? ?? 0,
      members: map['members'] as int? ?? 0,
      status: map['status'] as String?,
      releaseDate: map['releaseDate'] != null
          ? DateTime.tryParse(map['releaseDate'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      url: map['url'] as String?,
      chapters:
          (map['chapters'] as List<dynamic>?)
              ?.map((e) => Chapter.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalView: map['totalView'] as int? ?? 0,
    );
  }

  factory MangaDetail.fromMangaSummary(MangaSummary summary) {
    return MangaDetail(
      id: summary.id,
      malId: summary.malId,
      anilistId: summary.anilistId,
      mangaUpdateId: summary.mangaUpdateId,
      title: summary.title,
      author: summary.author,
      type: summary.type,
      genres: summary.genres,
      categories: summary.categories,
      description: summary.description ?? 'No description available',
      imageUrl: summary.imageUrl,
      localImageUrl: summary.localImageUrl,
      rating: summary.rating,
      popularity: summary.popularity,
      members: summary.members,
      status: summary.status,
      releaseDate: summary.releaseDate,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      url: summary.url,
      chapters: [],
      totalView: summary.totalView,
    );
  }

  String get displayImageUrl {
    return localImageUrl ?? imageUrl ?? '';
  }

  Chapter? getFirstChapter() {
    if (chapters.isEmpty) return null;
    return chapters.reduce((a, b) => a.chapterNumber < b.chapterNumber ? a : b);
  }

  Chapter? getLatestChapter() {
    if (chapters.isEmpty) return null;
    return chapters.reduce((a, b) => a.chapterNumber > b.chapterNumber ? a : b);
  }

  Chapter? getNextUnreadChapter(MangaProgression? progression) {
    if (chapters.isEmpty) return null;
    if (progression == null) return getFirstChapter();

    // Sort ascending by chapter number
    final sorted = List<Chapter>.from(chapters)
      ..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));

    // Find first chapter after current reading or with uncompleted log
    for (final ch in sorted) {
      final log = progression.chapterLogs
          .where((l) => l.chapterId == ch.id || l.chapterNumber == ch.chapterNumber)
          .firstOrNull;

      if (log == null || !log.isCompleted) {
        return ch;
      }
    }

    return sorted.lastOrNull;
  }

  double getReadPercentage(MangaProgression? progression) {
    if (chapters.isEmpty || progression == null) return 0.0;
    final readCount = progression.chapterLogs.where((l) => l.isCompleted).length;
    return (readCount / chapters.length).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'malId': malId,
      'anilistId': anilistId,
      'mangaUpdateId': mangaUpdateId,
      'title': title,
      'author': author,
      'type': type,
      'genres': genres,
      'categories': categories,
      'description': description,
      'imageUrl': imageUrl,
      'localImageUrl': localImageUrl,
      'rating': rating,
      'popularity': popularity,
      'members': members,
      'totalView': totalView,
      'status': status,
      'releaseDate': releaseDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'url': url,
      'chapters': chapters.map((c) => c.toMap()).toList(),
    };
  }

  String toJson() => jsonEncode(toMap());

  factory MangaDetail.fromJson(String json) =>
      MangaDetail.fromMap(jsonDecode(json) as Map<String, dynamic>);
}

class Chapter {
  final String id;
  final String title;
  final double chapterNumber;
  final DateTime date;
  final bool isNew;
  final bool isRead;
  final bool isChapterAvailable;
  final String? chapterProvider;
  final String? chapterProviderIcon;
  final String? link;
  final List<ChapterPage> pages;
  final String language;
  final int totalView;
  final int totalPages;
  final int brokenPageCount;

  Chapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.date,
    this.isNew = false,
    this.isRead = false,
    this.isChapterAvailable = false,
    this.chapterProvider,
    this.chapterProviderIcon,
    this.link,
    this.pages = const [],
    this.language = '',
    this.totalView = 0,
    this.totalPages = 0,
    this.brokenPageCount = 0,
  });

  List<String> get pageUrls => pages.map((p) => p.url).toList();
  int get pageCount => totalPages > 0 ? totalPages : pages.length;

  Chapter copyWith({
    String? id,
    String? title,
    double? chapterNumber,
    DateTime? date,
    bool? isNew,
    bool? isRead,
    bool? isChapterAvailable,
    String? chapterProvider,
    String? chapterProviderIcon,
    String? link,
    List<ChapterPage>? pages,
    String? language,
    int? totalView,
    int? totalPages,
    int? brokenPageCount,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      date: date ?? this.date,
      isNew: isNew ?? this.isNew,
      isRead: isRead ?? this.isRead,
      isChapterAvailable: isChapterAvailable ?? this.isChapterAvailable,
      chapterProvider: chapterProvider ?? this.chapterProvider,
      chapterProviderIcon: chapterProviderIcon ?? this.chapterProviderIcon,
      link: link ?? this.link,
      pages: pages ?? this.pages,
      language: language ?? this.language,
      totalView: totalView ?? this.totalView,
      totalPages: totalPages ?? this.totalPages,
      brokenPageCount: brokenPageCount ?? this.brokenPageCount,
    );
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    final rawPages = map['pages'] as List<dynamic>?;
    final List<ChapterPage> pagesList = rawPages
            ?.map((e) => ChapterPage.fromDynamic(e))
            .toList() ??
        [];
    final numVal = map['number'] ?? map['chapterNumber'] ?? 0;
    final int totalPages = (map['totalPages'] is num)
        ? (map['totalPages'] as num).toInt()
        : int.tryParse(map['totalPages']?.toString() ?? '') ?? pagesList.length;
    final int brokenPageCount = (map['brokenPageCount'] is num)
        ? (map['brokenPageCount'] as num).toInt()
        : int.tryParse(map['brokenPageCount']?.toString() ?? '') ?? 0;

    return Chapter(
      id: map['id'] as String? ?? (numVal.toString()),
      title: map['title'] as String? ?? 'Chapter $numVal',
      chapterNumber: (numVal as num).toDouble(),
      date: map['uploadDate'] != null
          ? (DateTime.tryParse(map['uploadDate'] as String) ?? DateTime.now())
          : map['date'] != null
          ? (DateTime.tryParse(map['date'] as String) ?? DateTime.now())
          : DateTime.now(),
      isNew: map['isNew'] as bool? ?? false,
      isRead: map['isRead'] as bool? ?? false,
      isChapterAvailable: map['isChapterAvailable'] as bool? ??
          (totalPages > 0 || pagesList.isNotEmpty),
      chapterProvider: map['chapterProvider'] as String?,
      chapterProviderIcon: map['chapterProviderIcon'] as String?,
      link: map['link'] as String?,
      pages: pagesList,
      language: map['language'] as String? ?? '',
      totalView: map['totalView'] as int? ?? 0,
      totalPages: totalPages,
      brokenPageCount: brokenPageCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'chapterNumber': chapterNumber,
      'number': chapterNumber,
      'date': date.toIso8601String(),
      'uploadDate': date.toIso8601String(),
      'isNew': isNew,
      'isRead': isRead,
      'isChapterAvailable': isChapterAvailable,
      'chapterProvider': chapterProvider,
      'chapterProviderIcon': chapterProviderIcon,
      'link': link,
      'pages': pages.map((p) => p.toMap()).toList(),
      'language': language,
      'totalView': totalView,
      'totalPages': totalPages,
      'brokenPageCount': brokenPageCount,
    };
  }
}
