class MangaSummary {
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
  final int? thumbnailSize;
  final double? rating;
  final int popularity;
  final int members;
  final DateTime? releaseDate;
  final bool? nsfw;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? url;
  final int totalView;
  final LatestChapterSummary? latestChapter;

  MangaSummary({
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
    this.thumbnailSize,
    this.rating,
    required this.popularity,
    required this.members,
    this.releaseDate,
    this.nsfw,
    this.status,
    required this.createdAt,
    required this.updatedAt,
    this.url,
    required this.totalView,
    this.latestChapter,
  });

  factory MangaSummary.fromJson(Map<String, dynamic> json) {
    return MangaSummary(
      id: json['id'] as String? ?? '',
      malId: json['malId'] as int? ?? 0,
      anilistId: json['anilistId'] as int?,
      mangaUpdateId: json['mangaUpdateId'] as int?,
      title: json['title'] as String? ?? 'Unknown Title',
      author: json['author'] as String? ?? 'Unknown Author',
      type: json['type'] as String? ?? 'Unknown',
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      localImageUrl: json['localImageUrl'] as String?,
      thumbnailSize: json['thumbnailSize'] as int?,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      popularity: json['popularity'] as int? ?? 0,
      members: json['members'] as int? ?? 0,
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'] as String)
          : null,
      nsfw: json['nsfw'] as bool?,
      status: json['status'] as String?,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      url: json['url'] as String?,
      totalView: json['totalView'] as int? ?? 0,
      latestChapter: json['latestChapter'] != null
          ? LatestChapterSummary.fromJson(
              json['latestChapter'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
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
      'thumbnailSize': thumbnailSize,
      'rating': rating,
      'popularity': popularity,
      'members': members,
      'releaseDate': releaseDate?.toIso8601String(),
      'nsfw': nsfw,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'url': url,
      'totalView': totalView,
      'latestChapter': latestChapter?.toJson(),
    };
  }

  String get displayImageUrl {
    if (localImageUrl != null && localImageUrl!.isNotEmpty) {
      return localImageUrl!;
    }
    return imageUrl ?? '';
  }
}

class LatestChapterSummary {
  final String id;
  final double number;
  final String? link;
  final List<String> pages;
  final String language;
  final String? chapterProvider;
  final String? chapterProviderIcon;
  final DateTime uploadDate;
  final int totalView;
  final int totalPages;
  final int brokenPageCount;

  LatestChapterSummary({
    required this.id,
    required this.number,
    this.link,
    this.pages = const [],
    this.language = '',
    this.chapterProvider,
    this.chapterProviderIcon,
    required this.uploadDate,
    required this.totalView,
    this.totalPages = 0,
    this.brokenPageCount = 0,
  });

  int get pageCount => totalPages > 0 ? totalPages : pages.length;
  bool get isChapterAvailable =>
      totalPages > 0 || pages.isNotEmpty || (link != null && link!.isNotEmpty);

  factory LatestChapterSummary.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>?;
    final pagesList = rawPages
            ?.map((e) => e is Map ? (e['url']?.toString() ?? '') : e.toString())
            .toList() ??
        [];
    final int totalPages = (json['totalPages'] is num)
        ? (json['totalPages'] as num).toInt()
        : int.tryParse(json['totalPages']?.toString() ?? '') ?? pagesList.length;
    final int brokenPageCount = (json['brokenPageCount'] is num)
        ? (json['brokenPageCount'] as num).toInt()
        : int.tryParse(json['brokenPageCount']?.toString() ?? '') ?? 0;

    return LatestChapterSummary(
      id: json['id'] as String? ?? '',
      number: (json['number'] as num? ?? json['chapterNumber'] as num? ?? 0).toDouble(),
      link: json['link'] as String?,
      pages: pagesList,
      language: json['language'] as String? ?? '',
      chapterProvider: json['chapterProvider'] as String?,
      chapterProviderIcon: json['chapterProviderIcon'] as String?,
      uploadDate: json['uploadDate'] != null
          ? (DateTime.tryParse(json['uploadDate'] as String) ?? DateTime.now())
          : DateTime.now(),
      totalView: json['totalView'] as int? ?? 0,
      totalPages: totalPages,
      brokenPageCount: brokenPageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'link': link,
      'pages': pages,
      'language': language,
      'chapterProvider': chapterProvider,
      'chapterProviderIcon': chapterProviderIcon,
      'uploadDate': uploadDate.toIso8601String(),
      'totalView': totalView,
      'totalPages': totalPages,
      'brokenPageCount': brokenPageCount,
    };
  }
}
