import 'dart:convert';
import '../../../core/models/manga_summary.dart';

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
      id: map['id']?.toString() ?? '',
      chapterId: map['chapterId']?.toString() ?? '',
      chapterNumber: ((map['chapterNumber'] ?? 0.0) as num).toDouble(),
      lastReadPage: (map['lastReadPage'] ?? 0) as int,
      totalPages: (map['totalPage'] ?? map['totalPages'] ?? 0) as int,
      isCompleted: map['isCompleted'] as bool? ?? false,
      readingTimeSeconds:
          (map['readTimeInSeconds'] ?? map['readingTimeSeconds'] ?? 0) as int,
      lastReadAt: _parseDate(map['lastReadAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'lastReadPage': lastReadPage,
      'totalPage': totalPages,
      'totalPages': totalPages,
      'isCompleted': isCompleted,
      'readTimeInSeconds': readingTimeSeconds,
      'readingTimeSeconds': readingTimeSeconds,
      'lastReadAt': lastReadAt.toIso8601String(),
    };
  }

  String get formattedReadingTime {
    if (readingTimeSeconds < 60) {
      return '${readingTimeSeconds}s';
    } else if (readingTimeSeconds < 3600) {
      return '${(readingTimeSeconds / 60).floor()}m';
    } else {
      final hours = (readingTimeSeconds / 3600).floor();
      final mins = ((readingTimeSeconds % 3600) / 60).floor();
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }
}

class MangaProgression {
  final String id;
  final String userId;
  final String mangaId;
  final DateTime lastReadAt;
  final List<UserChapterLog> chapterLogs;
  final int totalReadingTime;
  final MangaSummary? manga;

  MangaProgression({
    this.id = '',
    this.userId = '',
    required this.mangaId,
    DateTime? lastReadAt,
    DateTime? lastRead,
    List<UserChapterLog>? chapterLogs,
    this.totalReadingTime = 0,
    this.manga,
    String? chapterId,
    double? currentChapter,
    int? currentPage,
    int? totalPages,
    bool? isCompleted,
    int? readingTimeSeconds,
  })  : lastReadAt = lastReadAt ?? lastRead ?? DateTime.now(),
        chapterLogs = chapterLogs ??
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
                    ),
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

  String get formattedTotalReadingTime {
    if (totalReadingTime < 60) {
      return '${totalReadingTime}s read';
    } else if (totalReadingTime < 3600) {
      return '${(totalReadingTime / 60).floor()}m read';
    } else {
      final hours = (totalReadingTime / 3600).floor();
      final mins = ((totalReadingTime % 3600) / 60).floor();
      return mins > 0 ? '${hours}h ${mins}m read' : '${hours}h read';
    }
  }

  factory MangaProgression.fromMap(Map<String, dynamic> map) {
    final rawLogs = map['chapterLogs'] as List<dynamic>?;
    final List<UserChapterLog> logs = rawLogs != null
        ? rawLogs
            .map((e) => UserChapterLog.fromMap(e as Map<String, dynamic>))
            .toList()
        : [];

    if (logs.isEmpty &&
        (map['chapterId'] != null ||
            map['chapterNumber'] != null ||
            map['currentChapter'] != null)) {
      final oldChapterId = map['chapterId']?.toString() ?? '';
      final oldChapterNumber =
          ((map['chapterNumber'] ?? map['currentChapter'] ?? 0.0) as num)
              .toDouble();
      final oldLastReadPage =
          (map['lastReadPage'] ?? map['currentPage'] ?? 1) as int;
      final oldTotalPages = (map['totalPage'] ?? map['totalPages'] ?? 1) as int;
      final oldIsCompleted = map['isCompleted'] as bool? ?? false;
      final oldReadingTimeSeconds =
          (map['readTimeInSeconds'] ?? map['readingTimeSeconds'] ?? 0) as int;
      final oldLastReadAt = _parseDate(map['lastReadAt'] ?? map['lastRead']);
      logs.add(
        UserChapterLog(
          id: '',
          chapterId: oldChapterId,
          chapterNumber: oldChapterNumber,
          lastReadPage: oldLastReadPage,
          totalPages: oldTotalPages,
          isCompleted: oldIsCompleted,
          readingTimeSeconds: oldReadingTimeSeconds,
          lastReadAt: oldLastReadAt,
        ),
      );
    }

    final mangaObj = map['manga'] != null && map['manga'] is Map<String, dynamic>
        ? MangaSummary.fromJson(map['manga'] as Map<String, dynamic>)
        : null;

    final totalTime = (map['totalReadingTime'] ?? 0) as int;

    return MangaProgression(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      mangaId: map['mangaId']?.toString() ?? '',
      lastReadAt: _parseDate(map['lastReadAt'] ?? map['lastRead']),
      chapterLogs: logs,
      totalReadingTime: totalTime,
      manga: mangaObj,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
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
      if (manga != null) 'manga': manga!.toJson(),
    };
  }

  Map<String, dynamic> toApiRequest([String activeUserId = '']) {
    return {
      'userId': userId.isNotEmpty ? userId : activeUserId,
      'mangaId': mangaId,
      'chapterId': chapterId,
      'chapterNumber': currentChapter,
      'lastReadPage': currentPage,
      'totalPages': totalPages,
      'isCompleted': isCompleted,
      'readingTimeSeconds': readingTimeSeconds,
      'lastReadAt': lastReadAt.toUtc().toIso8601String(),
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
    MangaSummary? manga,
  }) {
    return MangaProgression(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mangaId: mangaId ?? this.mangaId,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      chapterLogs: chapterLogs ?? this.chapterLogs,
      totalReadingTime: totalReadingTime ?? this.totalReadingTime,
      manga: manga ?? this.manga,
    );
  }

  double get progressPercentage {
    if (totalPages <= 0) return 0.0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }
}

