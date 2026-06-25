import 'dart:convert';

class UserChapterLog {
  final String id;
  final String chapterId;
  final double chapterNumber;
  final int lastReadPage;
  final int totalPages;
  final bool isCompleted;
  final int readingTimeSeconds;
  final DateTime lastReadAt;

  UserChapterLog({
    this.id = '',
    required this.chapterId,
    required this.chapterNumber,
    required this.lastReadPage,
    required this.totalPages,
    required this.isCompleted,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });

  factory UserChapterLog.fromMap(Map<String, dynamic> map) {
    return UserChapterLog(
      id: map['id'] as String? ?? '',
      chapterId: map['chapterId'] as String? ?? '',
      chapterNumber: ((map['chapterNumber'] ?? 0.0) as num).toDouble(),
      lastReadPage: (map['lastReadPage'] ?? 0) as int,
      totalPages: (map['totalPages'] ?? 0) as int,
      isCompleted: map['isCompleted'] as bool? ?? false,
      readingTimeSeconds: (map['readingTimeSeconds'] ?? 0) as int,
      lastReadAt: _parseDate(map['lastReadAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'lastReadPage': lastReadPage,
      'totalPages': totalPages,
      'isCompleted': isCompleted,
      'readingTimeSeconds': readingTimeSeconds,
      'lastReadAt': lastReadAt.toIso8601String(),
    };
  }
}

class MangaProgression {
  final String id;
  final String userId;
  final String mangaId;
  final DateTime lastReadAt;
  final List<UserChapterLog> chapterLogs;
  final int totalReadingTime;

  MangaProgression({
    this.id = '',
    this.userId = '',
    required this.mangaId,
    DateTime? lastReadAt,
    DateTime? lastRead,
    List<UserChapterLog>? chapterLogs,
    this.totalReadingTime = 0,
    // Backwards compatibility params:
    String? chapterId,
    double? currentChapter,
    int? currentPage,
    int? totalPages,
    bool? isCompleted,
    int? readingTimeSeconds,
  })  : this.lastReadAt = lastReadAt ?? lastRead ?? DateTime.now(),
        this.chapterLogs = chapterLogs ??
            (chapterId != null && chapterId.isNotEmpty
                ? [
                    UserChapterLog(
                      id: '',
                      chapterId: chapterId,
                      chapterNumber: currentChapter ?? 0.0,
                      lastReadPage: currentPage ?? 0,
                      totalPages: totalPages ?? 0,
                      isCompleted: isCompleted ?? false,
                      readingTimeSeconds: readingTimeSeconds ?? 0,
                      lastReadAt: lastReadAt ?? lastRead ?? DateTime.now(),
                    )
                  ]
                : []);

  UserChapterLog? get _latestLog {
    if (chapterLogs.isEmpty) return null;
    final sorted = List<UserChapterLog>.from(chapterLogs)
      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return sorted.first;
  }

  String get chapterId => _latestLog?.chapterId ?? '';
  double get currentChapter => _latestLog?.chapterNumber ?? 0.0;
  int get currentPage => _latestLog?.lastReadPage ?? 0;
  int get totalPages => _latestLog?.totalPages ?? 0;
  bool get isCompleted => _latestLog?.isCompleted ?? false;
  int get readingTimeSeconds => _latestLog?.readingTimeSeconds ?? 0;
  DateTime get lastRead => lastReadAt;

  factory MangaProgression.fromMap(Map<String, dynamic> map) {
    final rawLogs = map['chapterLogs'] as List<dynamic>?;
    final List<UserChapterLog> logs = rawLogs != null
        ? rawLogs
            .map((e) => UserChapterLog.fromMap(e as Map<String, dynamic>))
            .toList()
        : [];

    // Also support parsing old format fields if chapterLogs is empty
    if (logs.isEmpty && (map['chapterId'] != null || map['chapterNumber'] != null || map['currentChapter'] != null)) {
      final oldChapterId = map['chapterId'] as String? ?? '';
      final oldChapterNumber = ((map['chapterNumber'] ?? map['currentChapter'] ?? 0.0) as num).toDouble();
      final oldLastReadPage = (map['lastReadPage'] ?? map['currentPage'] ?? 1) as int;
      final oldTotalPages = (map['totalPages'] ?? 1) as int;
      final oldIsCompleted = map['isCompleted'] as bool? ?? false;
      final oldReadingTimeSeconds = (map['readingTimeSeconds'] ?? 0) as int;
      final oldLastReadAt = _parseDate(map['lastReadAt'] ?? map['lastRead']);
      logs.add(UserChapterLog(
        id: '',
        chapterId: oldChapterId,
        chapterNumber: oldChapterNumber,
        lastReadPage: oldLastReadPage,
        totalPages: oldTotalPages,
        isCompleted: oldIsCompleted,
        readingTimeSeconds: oldReadingTimeSeconds,
        lastReadAt: oldLastReadAt,
      ));
    }

    return MangaProgression(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      mangaId: map['mangaId'] as String? ?? '',
      lastReadAt: _parseDate(map['lastReadAt'] ?? map['lastRead']),
      chapterLogs: logs,
      totalReadingTime: map['totalReadingTime'] as int? ?? 0,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mangaId': mangaId,
      'lastReadAt': lastReadAt.toIso8601String(),
      'chapterLogs': chapterLogs.map((e) => e.toMap()).toList(),
      'totalReadingTime': totalReadingTime,
    };
  }

  Map<String, dynamic> toApiRequest() {
    return {
      'mangaId': mangaId,
      'chapterId': chapterId,
      'chapterNumber': currentChapter,
      'lastReadPage': currentPage,
      'totalPages': totalPages,
      'readingTimeSeconds': readingTimeSeconds,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory MangaProgression.fromJson(String source) =>
      MangaProgression.fromMap(jsonDecode(source) as Map<String, dynamic>);

  MangaProgression copyWith({
    String? id,
    String? userId,
    String? mangaId,
    DateTime? lastReadAt,
    List<UserChapterLog>? chapterLogs,
    int? totalReadingTime,
  }) {
    return MangaProgression(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mangaId: mangaId ?? this.mangaId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      chapterLogs: chapterLogs ?? this.chapterLogs,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
    );
  }

  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }
}
