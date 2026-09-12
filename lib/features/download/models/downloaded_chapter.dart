import '../../../core/models/chapter_page.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../settings/services/storage_service.dart';

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled,
}

class DownloadedChapter {
  final String mangaId;
  final String mangaTitle;
  final String? mangaCoverUrl;
  final String chapterId;
  final double chapterNumber;
  final String chapterTitle;
  final int pageCount;
  final int sizeBytes;
  final DateTime downloadedAt;
  final List<String> pageFilePaths;

  const DownloadedChapter({
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCoverUrl,
    required this.chapterId,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.pageCount,
    required this.sizeBytes,
    required this.downloadedAt,
    required this.pageFilePaths,
  });

  bool get isComplete =>
      pageFilePaths.isNotEmpty && pageFilePaths.length >= pageCount;

  String get formattedSize => StorageService.formatBytes(sizeBytes);

  List<ChapterPage> toChapterPages() {
    return pageFilePaths.map((path) => ChapterPage(url: path)).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'mangaId': mangaId,
      'mangaTitle': mangaTitle,
      'mangaCoverUrl': mangaCoverUrl,
      'chapterId': chapterId,
      'chapterNumber': chapterNumber,
      'chapterTitle': chapterTitle,
      'pageCount': pageCount,
      'sizeBytes': sizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'pageFilePaths': pageFilePaths,
    };
  }

  factory DownloadedChapter.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['pageFilePaths'] as List<dynamic>?;
    final List<String> paths =
        rawPaths?.map((e) => e.toString()).toList() ?? [];

    return DownloadedChapter(
      mangaId: map['mangaId'] as String? ?? '',
      mangaTitle: map['mangaTitle'] as String? ?? '',
      mangaCoverUrl: map['mangaCoverUrl'] as String?,
      chapterId: map['chapterId'] as String? ?? '',
      chapterNumber: (map['chapterNumber'] is num)
          ? (map['chapterNumber'] as num).toDouble()
          : double.tryParse(map['chapterNumber']?.toString() ?? '0') ?? 0.0,
      chapterTitle: map['chapterTitle'] as String? ?? '',
      pageCount: (map['pageCount'] is num)
          ? (map['pageCount'] as num).toInt()
          : int.tryParse(map['pageCount']?.toString() ?? '0') ?? paths.length,
      sizeBytes: (map['sizeBytes'] is num)
          ? (map['sizeBytes'] as num).toInt()
          : int.tryParse(map['sizeBytes']?.toString() ?? '0') ?? 0,
      downloadedAt: map['downloadedAt'] != null
          ? (DateTime.tryParse(map['downloadedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
      pageFilePaths: paths,
    );
  }
}

class DownloadTask {
  final String mangaId;
  final String mangaTitle;
  final String? mangaCoverUrl;
  final Chapter chapter;
  final DownloadStatus status;
  final double _progress;
  final int downloadedPages;
  final int totalPages;
  final String? errorMessage;
  final int sizeBytes;

  const DownloadTask({
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCoverUrl,
    required this.chapter,
    this.status = DownloadStatus.queued,
    double progress = 0.0,
    this.downloadedPages = 0,
    this.totalPages = 0,
    this.errorMessage,
    this.sizeBytes = 0,
  }) : _progress = progress;

  double get progress =>
      totalPages > 0 ? (downloadedPages / totalPages).clamp(0.0, 1.0) : _progress;

  bool get isQueued => status == DownloadStatus.queued;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isCanceled => status == DownloadStatus.canceled;

  DownloadTask copyWith({
    String? mangaId,
    String? mangaTitle,
    String? mangaCoverUrl,
    Chapter? chapter,
    DownloadStatus? status,
    double? progress,
    int? downloadedPages,
    int? totalPages,
    String? errorMessage,
    int? sizeBytes,
  }) {
    return DownloadTask(
      mangaId: mangaId ?? this.mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      mangaCoverUrl: mangaCoverUrl ?? this.mangaCoverUrl,
      chapter: chapter ?? this.chapter,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedPages: downloadedPages ?? this.downloadedPages,
      totalPages: totalPages ?? this.totalPages,
      errorMessage: errorMessage ?? this.errorMessage,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
