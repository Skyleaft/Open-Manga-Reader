import 'dart:convert';

class MangaDetail {
  final String id;
  final int malId;
  final String title;
  final String author;
  final String type;
  final List<String>? genres;
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
    required this.title,
    required this.author,
    required this.type,
    this.genres,
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

  factory MangaDetail.fromMap(Map<String, dynamic> map) {
    return MangaDetail(
      id: map['id'] as String? ?? '',
      malId: map['malId'] as int? ?? map['malID'] as int? ?? 0,
      title: map['title'] as String? ?? 'Unknown Title',
      author: map['author'] as String? ?? 'Unknown Author',
      type: map['type'] as String? ?? 'Unknown Type',
      genres: (map['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      description: map['description'] as String? ?? 'No description available',
      imageUrl: map['imageUrl'] as String?,
      localImageUrl: map['localImageUrl'] as String?,
      rating: map['rating'] != null
          ? (map['rating'] as dynamic).toDouble()
          : null,
      popularity: map['popularity'] as int? ?? 0,
      members: map['members'] as int? ?? 0,

      status: map['status'] as String?,
      releaseDate: map['releaseDate'] != null
          ? DateTime.parse(map['releaseDate'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
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

  String get displayImageUrl {
    // This will be handled by the MangaApiService.getLocalImageUrl method
    // when the image is actually used in the UI
    return localImageUrl ?? imageUrl ?? '';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'malId': malId,
      'title': title,
      'author': author,
      'type': type,
      'genres': genres,
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
  final String language;
  final int totalView;

  Chapter({
    required this.id,
    required this.title,
    required this.chapterNumber,
    required this.date,
    this.isNew = false,
    this.isRead = false,
    this.isChapterAvailable = true,
    this.chapterProvider,
    this.chapterProviderIcon,
    this.link,
    this.language = '',
    this.totalView = 0,
  });

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as String? ?? (map['number']?.toString() ?? ''),
      title: map['title'] as String? ?? 'Chapter ${map['number']}',
      chapterNumber:
          (map['number'] as num? ?? map['chapterNumber'] as num? ?? 0)
              .toDouble(),
      date: map['uploadDate'] != null
          ? DateTime.parse(map['uploadDate'] as String)
          : map['date'] != null
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      isNew: map['isNew'] as bool? ?? false,
      isRead: map['isRead'] as bool? ?? false,
      isChapterAvailable: map['isChapterAvailable'] as bool? ?? true,
      chapterProvider: map['chapterProvider'] as String?,
      chapterProviderIcon: map['chapterProviderIcon'] as String?,
      link: map['link'] as String?,
      language: map['language'] as String? ?? '',
      totalView: map['totalView'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'chapterNumber': chapterNumber,
      'date': date.toIso8601String(),
      'isNew': isNew,
      'isRead': isRead,
      'isChapterAvailable': isChapterAvailable,
      'chapterProvider': chapterProvider,
      'chapterProviderIcon': chapterProviderIcon,
      'link': link,
      'language': language,
      'totalView': totalView,
    };
  }
}
