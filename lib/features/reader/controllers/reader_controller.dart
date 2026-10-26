import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/painting.dart';
import 'package:dio/dio.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../download/services/download_service.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../models/reader_content.dart';

class ReaderController extends ChangeNotifier {
  final MangaApiService? _apiService;
  final ProgressionService? _progressionService;
  final DownloadService? _downloadService;

  final ReaderContent _content;
  bool _disposed = false;

  late List<String> _pageUrls;
  late String _chapterId;
  late double _currentChapterNumber;
  final Map<int, double> _pageAspectRatios = {};

  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(1);
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _accumulatedBottomOverscrollNotifier =
      ValueNotifier<double>(0.0);
  double _targetProgress = 0.0;
  String? _errorMessage;

  bool _showUI = true;
  bool _isLoading = false;
  bool _isChangingChapter = false;
  DateTime _lastChapterChangeTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounceTimer;

  bool _isSliderScrolling = false;
  bool _isRestoringScroll = false;
  bool _isJumpingToPage = false;

  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.0;

  bool _isWebtoonMode = true;
  bool _isRtlMode = false;
  bool _hideMiniProgressBar = false;
  bool _isFullscreen = false;

  int _chapterInitialReadingTimeSeconds = 0;
  late DateTime _sessionStartTime;
  CancelToken? _chapterCancelToken;

  // Getters & ValueNotifiers for isolated sub-tree rendering
  ReaderContent get content => _content;
  List<String> get pageUrls => _pageUrls;
  String get chapterId => _chapterId;
  double get currentChapterNumber => _currentChapterNumber;
  Map<int, double> get pageAspectRatios => _pageAspectRatios;

  ValueNotifier<int> get currentPageNotifier => _currentPageNotifier;
  ValueNotifier<double> get progressNotifier => _progressNotifier;
  ValueNotifier<double> get accumulatedBottomOverscrollNotifier =>
      _accumulatedBottomOverscrollNotifier;

  int get currentPage => _currentPageNotifier.value;
  double get progress => _progressNotifier.value;
  double get accumulatedBottomOverscroll =>
      _accumulatedBottomOverscrollNotifier.value;
  double get targetProgress => _targetProgress;
  String? get errorMessage => _errorMessage;

  bool get showUI => _showUI;
  bool get isLoading => _isLoading;
  bool get isChangingChapter => _isChangingChapter;
  bool get isSliderScrolling => _isSliderScrolling;
  bool get isRestoringScroll => _isRestoringScroll;
  bool get isJumpingToPage => _isJumpingToPage;

  bool get isAutoScrolling => _isAutoScrolling;
  double get autoScrollSpeed => _autoScrollSpeed;

  bool get isWebtoonMode => _isWebtoonMode;
  bool get isRtlMode => _isRtlMode;
  bool get hideMiniProgressBar => _hideMiniProgressBar;
  bool get isFullscreen => _isFullscreen;

  ReaderController({
    required ReaderContent content,
    MangaApiService? apiService,
    ProgressionService? progressionService,
    DownloadService? downloadService,
  })  : _content = content,
        _apiService = apiService ??
            (getIt.isRegistered<MangaApiService>()
                ? getIt<MangaApiService>()
                : null),
        _progressionService = progressionService ??
            (getIt.isRegistered<ProgressionService>()
                ? getIt<ProgressionService>()
                : null),
        _downloadService = downloadService ??
            (getIt.isRegistered<DownloadService>()
                ? getIt<DownloadService>()
                : null) {
    _init();
  }

  void _init() {
    _pageUrls = _content.pageUrls;
    _chapterId = _content.chapterId;
    _currentChapterNumber = _content.currentChapterNumber;

    if (_content.pageAspectRatios != null) {
      _pageAspectRatios.addAll(_content.pageAspectRatios!);
    }

    if (_content.currentPage > 1 &&
        _content.currentPage <= _pageUrls.length) {
      _isRestoringScroll = true;
      _currentPageNotifier.value = _content.currentPage;
      _targetProgress = (_content.currentPage - 1) / (_pageUrls.length - 1);
      _progressNotifier.value = _targetProgress;
    } else {
      _currentPageNotifier.value = 1;
      _progressNotifier.value = 0.0;
    }

    _sessionStartTime = DateTime.now();
    loadInitialReadingTime();
    checkInitialFullscreen();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> checkInitialFullscreen() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (!_disposed) {
          _isFullscreen = isFull;
          _safeNotifyListeners();
        }
      } catch (e) {
        debugPrint('Window manager full screen check error: $e');
      }
    }
  }

  Future<void> toggleFullscreen() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
      if (!_disposed) {
        _isFullscreen = !isFull;
        _safeNotifyListeners();
      }
    } else {
      if (_isFullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      if (!_disposed) {
        _isFullscreen = !_isFullscreen;
        _safeNotifyListeners();
      }
    }
  }

  Future<void> loadInitialReadingTime({String? chapterId}) async {
    final targetChapterId = chapterId ?? _chapterId;
    try {
      final progression =
          _content.progression ??
          await _progressionService?.getProgression(_content.mangaId);
      if (progression != null && !_disposed) {
        final chapterLog = progression.chapterLogs
            .where((l) => l.chapterId == targetChapterId)
            .fold<UserChapterLog?>(
              null,
              (prev, l) => prev == null || l.lastReadAt.isAfter(prev.lastReadAt)
                  ? l
                  : prev,
            );
        _chapterInitialReadingTimeSeconds =
            chapterLog?.readingTimeSeconds ?? 0;
      }
    } catch (e) {
      debugPrint('Failed to load initial reading time: $e');
    }
  }

  void setPageAspectRatio(int index, double ratio) {
    _pageAspectRatios[index] = ratio;
  }

  double calculateAverageRatio() {
    if (_pageAspectRatios.isNotEmpty) {
      final sum = _pageAspectRatios.values.fold(0.0, (a, b) => a + b);
      return sum / _pageAspectRatios.length;
    }
    return 1.4;
  }

  double calculateEstimatedOffset(
    int targetIndex,
    double contentWidth, {
    double? maxScrollExtent,
    bool hasClients = false,
  }) {
    if (targetIndex <= 0 || _pageUrls.isEmpty) return 0.0;

    if (hasClients && maxScrollExtent != null && targetIndex >= _pageUrls.length - 1) {
      if (maxScrollExtent > 0) return maxScrollExtent;
    }

    if (hasClients && maxScrollExtent != null && _pageUrls.length > 1) {
      if (maxScrollExtent > 0 && _pageAspectRatios.length < (_pageUrls.length / 2)) {
        final progressRatio = targetIndex / (_pageUrls.length - 1);
        return progressRatio * maxScrollExtent;
      }
    }

    final avgRatio = calculateAverageRatio();
    double offset = 0.0;
    for (int i = 0; i < targetIndex; i++) {
      final ratio = _pageAspectRatios[i] ?? avgRatio;
      offset += contentWidth * ratio;
    }
    return offset;
  }

  void toggleUI() {
    _showUI = !_showUI;
    _safeNotifyListeners();
  }

  void setShowUI(bool value) {
    if (_showUI != value) {
      _showUI = value;
      _safeNotifyListeners();
    }
  }

  void toggleAutoScroll() {
    _isAutoScrolling = !_isAutoScrolling;
    if (_isAutoScrolling) {
      _showUI = false;
    }
    _safeNotifyListeners();
  }

  void setAutoScrolling(bool value) {
    if (_isAutoScrolling != value) {
      _isAutoScrolling = value;
      if (_isAutoScrolling) {
        _showUI = false;
      }
      _safeNotifyListeners();
    }
  }

  void setAutoScrollSpeed(double speed) {
    _autoScrollSpeed = speed;
    _safeNotifyListeners();
  }

  void setWebtoonMode(bool value) {
    _isWebtoonMode = value;
    _safeNotifyListeners();
  }

  void setRtlMode(bool value) {
    _isRtlMode = value;
    _safeNotifyListeners();
  }

  void setHideMiniProgressBar(bool value) {
    _hideMiniProgressBar = value;
    _safeNotifyListeners();
  }

  void setSliderScrolling(bool value) {
    _isSliderScrolling = value;
  }

  void setRestoringScroll(bool value) {
    _isRestoringScroll = value;
  }

  void setJumpingToPage(bool value) {
    _isJumpingToPage = value;
  }

  void setAccumulatedBottomOverscroll(double value) {
    if (_accumulatedBottomOverscrollNotifier.value != value) {
      _accumulatedBottomOverscrollNotifier.value = value;
    }
  }

  void addAccumulatedBottomOverscroll(double delta) {
    _accumulatedBottomOverscrollNotifier.value += delta;
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      _safeNotifyListeners();
    }
  }

  /// Isolated update for scroll and slider events without triggering full screen rebuilds!
  void updatePageAndProgress(int page, double progress, {bool notifyController = false}) {
    bool changed = false;
    if (_currentPageNotifier.value != page) {
      _currentPageNotifier.value = page;
      changed = true;
    }
    if (_progressNotifier.value != progress) {
      _progressNotifier.value = progress;
      changed = true;
    }
    if (notifyController && changed) {
      _safeNotifyListeners();
    }
  }

  void debounceSaveProgression({Function(String message)? onError}) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      saveProgression(onError: onError);
    });
  }

  void cancelDebounceTimer() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
  }

  Future<void> saveProgression({Function(String message)? onError}) async {
    if (_progressionService == null) return;
    final isCompleted =
        _pageUrls.isNotEmpty && currentPage >= _pageUrls.length;

    final now = DateTime.now();
    final sessionSeconds = now.difference(_sessionStartTime).inSeconds;

    _sessionStartTime = now;
    _chapterInitialReadingTimeSeconds += sessionSeconds;

    try {
      MangaProgression? existingProgression = await _progressionService
          .getProgression(_content.mangaId);

      List<UserChapterLog> logs =
          existingProgression?.chapterLogs.toList() ?? [];
      final existingLogIndex =
          logs.indexWhere((l) => l.chapterId == _chapterId);

      if (existingLogIndex >= 0) {
        final existingLog = logs[existingLogIndex];
        logs[existingLogIndex] = UserChapterLog(
          id: existingLog.id,
          chapterId: _chapterId,
          chapterNumber: _currentChapterNumber,
          lastReadPage: currentPage,
          totalPages: _pageUrls.length,
          isCompleted: isCompleted,
          readingTimeSeconds: _chapterInitialReadingTimeSeconds,
          lastReadAt: now,
        );
      } else {
        logs.add(
          UserChapterLog(
            id: '',
            chapterId: _chapterId,
            chapterNumber: _currentChapterNumber,
            lastReadPage: currentPage,
            totalPages: _pageUrls.length,
            isCompleted: isCompleted,
            readingTimeSeconds: _chapterInitialReadingTimeSeconds,
            lastReadAt: now,
          ),
        );
      }

      final progression = MangaProgression(
        id: existingProgression?.id ?? '',
        userId: existingProgression?.userId ?? '',
        mangaId: _content.mangaId,
        chapterLogs: logs,
        lastReadAt: now,
        totalReadingTime: existingProgression?.totalReadingTime ?? 0,
        chapterId: _chapterId,
        currentChapter: _currentChapterNumber,
        currentPage: currentPage,
        totalPages: _pageUrls.length,
        isCompleted: isCompleted,
        readingTimeSeconds: _chapterInitialReadingTimeSeconds,
        manga: existingProgression?.manga,
      );

      await _progressionService.saveProgression(progression);
    } catch (e) {
      debugPrint('Progression save error: $e');
      onError?.call('Failed to save progress: $e');
    }
  }

  Future<void> changeChapter({
    required bool next,
    required VoidCallback onChapterNotFound,
    Function(String message)? onError,
    VoidCallback? onBeforeLoad,
    VoidCallback? onLoaded,
  }) async {
    if (_isChangingChapter || _isLoading) return;

    final now = DateTime.now();
    if (now.difference(_lastChapterChangeTime).inMilliseconds < 600) {
      return;
    }

    final targetChapter = next
        ? _content.getNextChapter(_chapterId, _currentChapterNumber)
        : _content.getPreviousChapter(_chapterId, _currentChapterNumber);

    if (targetChapter == null) {
      onChapterNotFound();
      return;
    }

    _isChangingChapter = true;
    _accumulatedBottomOverscrollNotifier.value = 0.0;

    _isLoading = true;
    _isRestoringScroll = true;
    _isJumpingToPage = true;
    _safeNotifyListeners();

    onBeforeLoad?.call();

    if (next && _pageUrls.isNotEmpty) {
      cancelDebounceTimer();
      _currentPageNotifier.value = _pageUrls.length;
      _progressNotifier.value = 1.0;
      try {
        await saveProgression(onError: onError);
      } catch (e) {
        debugPrint('Failed to save progression: $e');
      }
    }

    await _loadChapterInternal(
      targetChapter,
      onError: onError,
      onLoaded: onLoaded,
    );
  }

  Future<void> loadChapter(
    Chapter targetChapter, {
    int initialPage = 1,
    Function(String message)? onError,
    VoidCallback? onBeforeLoad,
    VoidCallback? onLoaded,
  }) async {
    if (_isChangingChapter || _isLoading) return;
    if (targetChapter.id == _chapterId) return;

    _isChangingChapter = true;
    _accumulatedBottomOverscrollNotifier.value = 0.0;

    _isLoading = true;
    _isRestoringScroll = true;
    _isJumpingToPage = true;
    _safeNotifyListeners();

    onBeforeLoad?.call();

    await _loadChapterInternal(
      targetChapter,
      initialPage: initialPage,
      onError: onError,
      onLoaded: onLoaded,
    );
  }

  Future<void> retryCurrentChapter({
    Function(String message)? onError,
    VoidCallback? onBeforeLoad,
    VoidCallback? onLoaded,
  }) async {
    _errorMessage = null;
    final currentChapter = _content.allChapters.firstWhere(
      (c) => c.id == _chapterId,
      orElse: () => Chapter(
        id: _chapterId,
        title: 'Chapter $_currentChapterNumber',
        chapterNumber: _currentChapterNumber,
        date: DateTime.now(),
      ),
    );
    await loadChapter(
      currentChapter,
      initialPage: currentPage,
      onError: onError,
      onBeforeLoad: onBeforeLoad,
      onLoaded: onLoaded,
    );
  }

  Future<void> _loadChapterInternal(
    Chapter targetChapter, {
    int initialPage = 1,
    Function(String message)? onError,
    VoidCallback? onLoaded,
  }) async {
    _chapterCancelToken?.cancel();
    _chapterCancelToken = CancelToken();

    try {
      final downloaded = _downloadService?.getDownloadedChapter(
        _content.mangaId,
        targetChapter.id,
      );

      List<String> targetPageUrls;
      if (downloaded != null && downloaded.isComplete) {
        targetPageUrls = downloaded.pageFilePaths;
      } else {
        if (_apiService == null) return;
        _apiService.incrementChapterView(
          _content.mangaId,
          targetChapter.id,
        );

        final pages = await _apiService.getChapterPages(
          _content.mangaId,
          targetChapter.id,
          cancelToken: _chapterCancelToken,
        );

        for (int i = 0; i < pages.length; i++) {
          if (pages[i].aspectRatio != null) {
            _pageAspectRatios[i] = pages[i].aspectRatio!;
          }
        }

        targetPageUrls = pages
            .map((p) => _apiService.getLocalImageUrl(p.url, null))
            .toList();
      }

      PaintingBinding.instance.imageCache.clearLiveImages();
      _pageAspectRatios.clear();
      await saveProgression(onError: onError);

      _sessionStartTime = DateTime.now();
      _chapterInitialReadingTimeSeconds = 0;

      final safeInitialPage = initialPage.clamp(
        1,
        targetPageUrls.isEmpty ? 1 : targetPageUrls.length,
      );

      _pageUrls = targetPageUrls;
      _chapterId = targetChapter.id;
      _currentChapterNumber = targetChapter.chapterNumber;
      _progressNotifier.value = targetPageUrls.length > 1
          ? (safeInitialPage - 1) / (targetPageUrls.length - 1)
          : 0.0;
      _currentPageNotifier.value = safeInitialPage;
      _isLoading = false;
      _isRestoringScroll = true;
      _isJumpingToPage = true;
      _accumulatedBottomOverscrollNotifier.value = 0.0;
      _errorMessage = null;
      _safeNotifyListeners();

      onLoaded?.call();

      loadInitialReadingTime(chapterId: targetChapter.id);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      _isLoading = false;
      _isRestoringScroll = false;
      _isJumpingToPage = false;
      _accumulatedBottomOverscrollNotifier.value = 0.0;
      _errorMessage = 'Failed to load chapter: $e';
      _safeNotifyListeners();
      onError?.call('Failed to load chapter: $e');
    } finally {
      _isChangingChapter = false;
      _lastChapterChangeTime = DateTime.now();
      _safeNotifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _chapterCancelToken?.cancel();
    _debounceTimer?.cancel();
    _currentPageNotifier.dispose();
    _progressNotifier.dispose();
    _accumulatedBottomOverscrollNotifier.dispose();
    super.dispose();
  }
}
