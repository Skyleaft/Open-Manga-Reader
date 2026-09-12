import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/models/manga_summary.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../library/models/library_manga.dart';
import '../../library/services/library_service.dart';
import '../models/chapter_scraping_progress.dart';
import '../models/manga_detail.dart';
import '../services/manga_detail_service.dart';
import '../services/manga_signalr_service.dart';
import '../../../core/services/network_status_service.dart';

enum ChapterFilterOption {
  all,
  unreadOnly,
  readOnly,
}

class MangaDetailController extends ChangeNotifier {
  final MangaDetail manga;
  final MangaApiService _apiService;
  final ProgressionService _progressionService;
  final LibraryService _libraryService;
  final MangaDetailService _detailService;
  final MangaSignalRService _signalRService;

  List<Chapter> _chapters = [];
  bool _isLoadingChapters = true;
  bool _isInLibrary = false;
  bool _isFavorite = false;
  String? _libraryStatus;
  MangaProgression? _progression;
  List<MangaSummary> _recommendations = [];
  bool _isLoadingRecommendations = false;
  String? _recommendationErrorMessage;
  String? _recommendationStatus;
  String? _recommendationType;
  List<String> _recommendationGenres = [];
  List<MangaSummary> _similarByCategory = [];
  bool _isLoadingSimilarByCategory = false;
  String? _similarByCategoryErrorMessage;
  String? _similarCategoryStatus;
  String? _similarCategoryType;
  List<String> _similarCategoryGenres = [];
  List<String> _selectedCategories = [];
  bool _isAscending = false;
  String _searchQuery = '';
  ChapterFilterOption _chapterFilter = ChapterFilterOption.all;
  ChapterScrapingProgress? _scrapingProgress;

  Map<double, UserChapterLog> _chapterLogsMap = {};
  Chapter? _targetChapter;
  List<Chapter> _filteredChaptersCache = [];

  Timer? _searchDebounce;
  Timer? _clearScrapingTimer;
  CancelToken? _chaptersCancelToken;
  CancelToken? _recommendationsCancelToken;
  CancelToken? _similarCategoryCancelToken;
  StreamSubscription<ChapterScrapingProgress>? _progressSubscription;
  StreamSubscription<ChaptersUpdatedEvent>? _chaptersUpdatedSubscription;

  List<Chapter> get chapters => _chapters;
  List<Chapter> get filteredChapters => _filteredChaptersCache;
  Chapter? get targetChapter => _targetChapter;
  bool _isMangaNotFound = false;
  bool get isMangaNotFound => _isMangaNotFound;
  bool get isLoadingChapters => _isLoadingChapters;
  bool get isInLibrary => _isInLibrary;
  bool get isFavorite => _isFavorite;
  String? get libraryStatus => _libraryStatus;
  MangaProgression? get progression => _progression;
  List<MangaSummary> get recommendations => _recommendations;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  String? get recommendationErrorMessage => _recommendationErrorMessage;
  String? get recommendationStatus => _recommendationStatus;
  String? get recommendationType => _recommendationType;
  List<String> get recommendationGenres =>
      List.unmodifiable(_recommendationGenres);
  int get recommendationFilterCount =>
      (_recommendationStatus != null ? 1 : 0) +
      (_recommendationType != null ? 1 : 0) +
      _recommendationGenres.length;
  bool get hasRecommendationFilters => recommendationFilterCount > 0;
  List<MangaSummary> get similarByCategory => _similarByCategory;
  bool get isLoadingSimilarByCategory => _isLoadingSimilarByCategory;
  String? get similarByCategoryErrorMessage => _similarByCategoryErrorMessage;
  String? get similarCategoryStatus => _similarCategoryStatus;
  String? get similarCategoryType => _similarCategoryType;
  List<String> get similarCategoryGenres =>
      List.unmodifiable(_similarCategoryGenres);
  List<String> get selectedCategories => List.unmodifiable(_selectedCategories);
  int get similarCategoryFilterCount =>
      (_similarCategoryStatus != null ? 1 : 0) +
      (_similarCategoryType != null ? 1 : 0) +
      _similarCategoryGenres.length +
      _selectedCategories.length;
  bool get hasSimilarCategoryFilters => similarCategoryFilterCount > 0;
  bool get isAscending => _isAscending;
  String get searchQuery => _searchQuery;
  ChapterFilterOption get chapterFilter => _chapterFilter;
  ChapterScrapingProgress? get scrapingProgress => _scrapingProgress;
  bool get isScrapingActive =>
      _scrapingProgress != null &&
      !_scrapingProgress!.isCompleted &&
      !_scrapingProgress!.isFailed;

  UserChapterLog? getLogForChapter(double chapterNumber) =>
      _chapterLogsMap[chapterNumber];

  MangaDetailController({
    required this.manga,
    MangaApiService? apiService,
    ProgressionService? progressionService,
    LibraryService? libraryService,
    MangaDetailService? detailService,
    MangaSignalRService? signalRService,
  }) : _apiService = apiService ?? getIt<MangaApiService>(),
       _progressionService = progressionService ?? getIt<ProgressionService>(),
       _libraryService = libraryService ?? getIt<LibraryService>(),
       _detailService = detailService ?? getIt<MangaDetailService>(),
       _signalRService = signalRService ?? getIt<MangaSignalRService>() {
    _chapters = List.from(manga.chapters);
    _isLoadingChapters = manga.chapters.isEmpty;
    if (_chapters.isNotEmpty) {
      _sortChapters();
    } else {
      _updateDerivedState();
    }
    _progressionService.addListener(_onProgressionServiceChanged);
  }

  void _onProgressionServiceChanged() {
    _reloadProgressionFromCache();
  }

  Future<void> _reloadProgressionFromCache() async {
    final cached = await _progressionService.getProgression(manga.id);
    _progression = cached;
    _updateDerivedState();
    notifyListeners();
  }

  Future<void> init() async {
    // 1. Fast local cache lookup (runs immediately without blocking UI)
    await Future.wait([
      _loadProgression(),
      _checkIfInLibrary(),
    ]);

    // 2. Defer heavy background sync & SignalR connection until after page transition completes
    Future.delayed(const Duration(milliseconds: 180), () {
      final isOffline = getIt.isRegistered<NetworkStatusService>() &&
          !getIt<NetworkStatusService>().isOnline;
      if (!isOffline) {
        _initSignalR();
      }
      _loadChapters();
    });
  }

  void _initSignalR() {
    _signalRService.joinMangaGroup(manga.id);

    _progressSubscription =
        _signalRService.scrapingProgressStream.listen((progress) {
      if (progress.mangaId == manga.id) {
        _clearScrapingTimer?.cancel();
        _scrapingProgress = progress;
        notifyListeners();

        if (progress.isCompleted) {
          // Silently refresh chapters after completion
          Future.delayed(const Duration(milliseconds: 1200), () {
            _silentRefreshChapters();
          });
          // Auto-clear banner after 3.5 seconds
          _clearScrapingTimer = Timer(const Duration(milliseconds: 3500), () {
            _scrapingProgress = null;
            notifyListeners();
          });
        }
      }
    });

    _chaptersUpdatedSubscription =
        _signalRService.chaptersUpdatedStream.listen((event) {
      if (event.mangaId == manga.id) {
        _silentRefreshChapters();
      }
    });
  }

  void startScrapingFeedback() {
    _clearScrapingTimer?.cancel();
    _scrapingProgress = ChapterScrapingProgress(
      mangaId: manga.id,
      mangaTitle: manga.title,
      chapterId: '',
      chapterNumber: 0,
      downloadedPages: 0,
      totalPages: 0,
      percent: 0,
      status: 'Starting',
    );
    notifyListeners();
  }

  void clearScrapingProgress() {
    _clearScrapingTimer?.cancel();
    _scrapingProgress = null;
    notifyListeners();
  }

  Future<void> _silentRefreshChapters() async {
    try {
      final chaptersData = await _apiService.getMangaChapters(manga.id);
      _chapters = chaptersData.map((e) => Chapter.fromMap(e)).toList();
      _sortChapters();
      final freshDetail = _buildUpdatedDetail(_chapters);
      await _detailService.saveDetail(freshDetail);
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        await _handleMangaDeleted();
      }
    }
  }

  Future<void> pauseSignalR() async {
    await _signalRService.leaveMangaGroupAndDisconnect(manga.id);
  }

  Future<void> resumeSignalR() async {
    await _signalRService.joinMangaGroup(manga.id);
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void cancelPendingRequests() {
    _chaptersCancelToken?.cancel();
    _recommendationsCancelToken?.cancel();
    _similarCategoryCancelToken?.cancel();
    _searchDebounce?.cancel();
    _clearScrapingTimer?.cancel();
  }

  @override
  void dispose() {
    _isDisposed = true;
    cancelPendingRequests();
    _progressionService.removeListener(_onProgressionServiceChanged);
    _progressSubscription?.cancel();
    _chaptersUpdatedSubscription?.cancel();
    _signalRService.leaveMangaGroupAndDisconnect(manga.id);
    super.dispose();
  }

  void _updateDerivedState() {
    _chapterLogsMap = {};
    if (_progression != null) {
      for (final log in _progression!.chapterLogs) {
        _chapterLogsMap[log.chapterNumber] = log;
      }
    }

    _targetChapter = null;
    if (_chapters.isNotEmpty) {
      final available = _chapters.where((c) => c.isChapterAvailable).toList();
      if (available.isNotEmpty) {
        if (_progression != null && _progression!.currentChapter > 0) {
          _targetChapter = available
              .where((c) => c.chapterNumber == _progression!.currentChapter)
              .firstOrNull;
        }
        _targetChapter ??= available.reduce(
          (a, b) => a.chapterNumber < b.chapterNumber ? a : b,
        );
      }
    }

    _filteredChaptersCache = _computeFilteredChapters();
  }

  List<Chapter> _computeFilteredChapters() {
    if (_chapters.isEmpty) return const [];

    final hasQuery = _searchQuery.isNotEmpty;
    final query = hasQuery ? _searchQuery.toLowerCase() : '';

    return _chapters.where((c) {
      // 1. Search Query Filter
      if (hasQuery) {
        final titleMatch = c.title.toLowerCase().contains(query);
        final numberMatch = c.chapterNumber.toString().contains(query);
        if (!titleMatch && !numberMatch) return false;
      }

      // 2. Read / Unread Status Filter
      if (_chapterFilter != ChapterFilterOption.all) {
        final isRead = isChapterRead(c);
        if (_chapterFilter == ChapterFilterOption.unreadOnly && isRead) {
          return false;
        }
        if (_chapterFilter == ChapterFilterOption.readOnly && !isRead) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool isChapterRead(Chapter chapter) {
    final log = _chapterLogsMap[chapter.chapterNumber];
    if (log != null) {
      return log.isCompleted ||
          (log.lastReadPage > 0 && log.lastReadPage >= log.totalPages);
    }
    if (_progression != null) {
      return chapter.chapterNumber <= _progression!.currentChapter;
    }
    return false;
  }

  void setChapterFilter(ChapterFilterOption filter) {
    _chapterFilter = filter;
    _filteredChaptersCache = _computeFilteredChapters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150), () {
      _searchQuery = query.trim();
      _filteredChaptersCache = _computeFilteredChapters();
      notifyListeners();
    });
  }

  void toggleSort() {
    _isAscending = !_isAscending;
    _sortChapters();
    notifyListeners();
  }

  void _sortChapters() {
    _chapters.sort((a, b) {
      if (_isAscending) {
        return a.chapterNumber.compareTo(b.chapterNumber);
      } else {
        return b.chapterNumber.compareTo(a.chapterNumber);
      }
    });
    _updateDerivedState();
  }

  Future<void> refreshProgression() async {
    _progression = await _progressionService.syncProgressionFromApi(manga.id);
    notifyListeners();
  }

  Future<void> _loadProgression() async {
    // 1. Load from local cache first for instant display
    final cached = await _progressionService.getProgression(
      manga.id,
      syncFromApi: false,
    );
    if (cached != null) {
      _progression = cached;
      notifyListeners();
    }

    // 2. Background sync from API
    final synced = await _progressionService.getProgression(
      manga.id,
      syncFromApi: true,
    );
    if (synced != null && synced != _progression) {
      _progression = synced;
      notifyListeners();
    }
  }

  Future<void> _loadChapters() async {
    // 1. Load from local cache first for instant offline display
    if (_chapters.isEmpty) {
      final cached = await _detailService.getDetail(manga.id);
      if (cached != null && cached.chapters.isNotEmpty) {
        _chapters = cached.chapters;
        _sortChapters();
        _isLoadingChapters = false;
        notifyListeners();
      }
    }

    final isOffline = getIt.isRegistered<NetworkStatusService>() &&
        !getIt<NetworkStatusService>().isOnline;
    if (isOffline) {
      _isLoadingChapters = false;
      notifyListeners();
      return;
    }

    final isStale = await _detailService.isCacheStale(manga.id);
    if (!isStale && _chapters.isNotEmpty) {
      _isLoadingChapters = false;
      return;
    }

    // 2. Background sync from API with CancelToken
    _chaptersCancelToken?.cancel();
    _chaptersCancelToken = CancelToken();

    try {
      final chaptersData = await _apiService.getMangaChapters(
        manga.id,
        cancelToken: _chaptersCancelToken,
      );
      _chapters = chaptersData.map((e) => Chapter.fromMap(e)).toList();
      _sortChapters();
      _isLoadingChapters = false;

      final freshDetail = _buildUpdatedDetail(_chapters);
      await _detailService.saveDetail(freshDetail);
      await _detailService.pruneOldCache();
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (e is DioException && e.response?.statusCode == 404) {
        await _handleMangaDeleted();
        return;
      }
      if (_chapters.isEmpty) {
        _isLoadingChapters = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    _isLoadingChapters = true;
    notifyListeners();

    _chaptersCancelToken?.cancel();
    _chaptersCancelToken = CancelToken();

    try {
      final chaptersData = await _apiService.getMangaChapters(
        manga.id,
        cancelToken: _chaptersCancelToken,
      );
      _chapters = chaptersData.map((e) => Chapter.fromMap(e)).toList();
      _sortChapters();
      _isLoadingChapters = false;

      final freshDetail = _buildUpdatedDetail(_chapters);
      await _detailService.saveDetail(freshDetail);
      await refreshProgression();
      await _checkIfInLibrary();
      if (_recommendations.isNotEmpty) {
        loadRecommendations(forceReload: true);
      }
      if (_similarByCategory.isNotEmpty) {
        loadSimilarByCategory(forceReload: true);
      }
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      if (e is DioException && e.response?.statusCode == 404) {
        await _handleMangaDeleted();
        return;
      }
      _isLoadingChapters = false;
      notifyListeners();
    }
  }

  Future<void> _handleMangaDeleted() async {
    _isMangaNotFound = true;
    _isLoadingChapters = false;
    _chapters = [];
    _updateDerivedState();

    // 1. Remove detail cache from Hive
    await _detailService.removeDetail(manga.id);

    // 2. Remove from local library if present
    if (_isInLibrary) {
      await _libraryService.removeFromLibrary(manga.id);
      _isInLibrary = false;
      _isFavorite = false;
      _libraryStatus = null;
    }

    // 3. Remove progression/history from local Hive
    await _progressionService.deleteProgression(manga.id);
    _progression = null;

    notifyListeners();
  }

  Future<void> _checkIfInLibrary() async {
    final libraryItem = await _libraryService.getLibraryManga(manga.id);
    _isInLibrary = libraryItem != null;
    _isFavorite = libraryItem?.isFavorite ?? false;
    _libraryStatus = libraryItem?.status;
    notifyListeners();
  }

  Future<void> loadRecommendations({bool forceReload = false}) async {
    if (_isLoadingRecommendations) return;
    if (!forceReload && _recommendations.isNotEmpty) return;

    _isLoadingRecommendations = true;
    _recommendationErrorMessage = null;
    notifyListeners();

    _recommendationsCancelToken?.cancel();
    _recommendationsCancelToken = CancelToken();

    try {
      final recs = await _apiService.getSimilarMangaFiltered(
        manga.id,
        status: _recommendationStatus,
        type: _recommendationType,
        genres: _recommendationGenres.isNotEmpty ? _recommendationGenres : null,
        limit: 20,
      );
      _recommendations = recs;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _recommendationErrorMessage = e.toString();
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  Future<void> setRecommendationFilters({
    String? status,
    String? type,
    List<String>? genres,
  }) async {
    _recommendationStatus = status;
    _recommendationType = type;
    _recommendationGenres = genres != null ? List.from(genres) : [];
    await loadRecommendations(forceReload: true);
  }

  Future<void> toggleRecommendationGenre(String genre) async {
    if (_recommendationGenres.contains(genre)) {
      _recommendationGenres.remove(genre);
    } else {
      _recommendationGenres.add(genre);
    }
    await loadRecommendations(forceReload: true);
  }

  Future<void> removeRecommendationGenre(String genre) async {
    if (_recommendationGenres.remove(genre)) {
      await loadRecommendations(forceReload: true);
    }
  }

  Future<void> setRecommendationType(String? type) async {
    if (_recommendationType == type) {
      _recommendationType = null;
    } else {
      _recommendationType = type;
    }
    await loadRecommendations(forceReload: true);
  }

  Future<void> setRecommendationStatus(String? status) async {
    if (_recommendationStatus == status) {
      _recommendationStatus = null;
    } else {
      _recommendationStatus = status;
    }
    await loadRecommendations(forceReload: true);
  }

  Future<void> clearRecommendationFilters() async {
    if (!hasRecommendationFilters) return;
    _recommendationStatus = null;
    _recommendationType = null;
    _recommendationGenres = [];
    await loadRecommendations(forceReload: true);
  }

  Future<void> loadSimilarByCategory({bool forceReload = false}) async {
    if (_isLoadingSimilarByCategory) return;
    if (!forceReload && _similarByCategory.isNotEmpty) return;

    _isLoadingSimilarByCategory = true;
    _similarByCategoryErrorMessage = null;
    notifyListeners();

    _similarCategoryCancelToken?.cancel();
    _similarCategoryCancelToken = CancelToken();

    try {
      final categoriesToUse = _selectedCategories.isNotEmpty
          ? _selectedCategories
          : (manga.categories ?? []);

      List<MangaSummary> results;
      if (categoriesToUse.isNotEmpty) {
        results = await _apiService.getSimilarMangaByCategory(
          categories: categoriesToUse,
          status: _similarCategoryStatus,
          type: _similarCategoryType,
          genres: _similarCategoryGenres.isNotEmpty
              ? _similarCategoryGenres
              : null,
          excludeMangaId: manga.id,
          limit: 20,
          cancelToken: _similarCategoryCancelToken,
        );
      } else {
        results = await _apiService.getSimilarMangaByIdCategories(
          manga.id,
          status: _similarCategoryStatus,
          type: _similarCategoryType,
          genres: _similarCategoryGenres.isNotEmpty
              ? _similarCategoryGenres
              : null,
          limit: 20,
          cancelToken: _similarCategoryCancelToken,
        );
      }
      _similarByCategory = results;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      _similarByCategoryErrorMessage = e.toString();
    } finally {
      _isLoadingSimilarByCategory = false;
      notifyListeners();
    }
  }

  Future<void> toggleCategory(String category) async {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    await loadSimilarByCategory(forceReload: true);
  }

  Future<void> setSimilarCategoryFilters({
    String? status,
    String? type,
    List<String>? genres,
    List<String>? categories,
  }) async {
    _similarCategoryStatus = status;
    _similarCategoryType = type;
    _similarCategoryGenres = genres != null ? List.from(genres) : [];
    if (categories != null) {
      _selectedCategories = List.from(categories);
    }
    await loadSimilarByCategory(forceReload: true);
  }

  Future<void> clearSimilarCategoryFilters() async {
    _similarCategoryStatus = null;
    _similarCategoryType = null;
    _similarCategoryGenres.clear();
    _selectedCategories.clear();
    await loadSimilarByCategory(forceReload: true);
  }

  Future<void> toggleSimilarCategoryGenre(String genre) async {
    if (_similarCategoryGenres.contains(genre)) {
      _similarCategoryGenres.remove(genre);
    } else {
      _similarCategoryGenres.add(genre);
    }
    await loadSimilarByCategory(forceReload: true);
  }

  Future<void> removeSimilarCategoryGenre(String genre) async {
    if (_similarCategoryGenres.remove(genre)) {
      await loadSimilarByCategory(forceReload: true);
    }
  }

  Future<void> setSimilarCategoryType(String? type) async {
    if (_similarCategoryType == type) {
      _similarCategoryType = null;
    } else {
      _similarCategoryType = type;
    }
    await loadSimilarByCategory(forceReload: true);
  }

  Future<void> setSimilarCategoryStatus(String? status) async {
    if (_similarCategoryStatus == status) {
      _similarCategoryStatus = null;
    } else {
      _similarCategoryStatus = status;
    }
    await loadSimilarByCategory(forceReload: true);
  }

  Future<bool> toggleFavorite() async {
    if (!_isInLibrary) return false;
    await _libraryService.toggleFavorite(manga.id);
    _isFavorite = !_isFavorite;
    notifyListeners();
    return _isFavorite;
  }

  Future<void> addToLibrary(String status) async {
    final libraryManga = LibraryManga.fromMangaDetail(
      manga.id,
      manga.title,
      manga.author,
      manga.imageUrl ?? '',
      manga.url,
      manga.type,
      status: status,
    );

    await _libraryService.addToLibrary(libraryManga);
    _isInLibrary = true;
    _libraryStatus = status;
    notifyListeners();
  }

  Future<void> updateLibraryStatus(String newStatus) async {
    if (!_isInLibrary) return;
    await _libraryService.updateStatus(manga.id, newStatus);
    _libraryStatus = newStatus;
    notifyListeners();
  }

  Future<void> removeFromLibrary() async {
    if (!_isInLibrary) return;
    await _libraryService.removeFromLibrary(manga.id);
    _isInLibrary = false;
    _libraryStatus = null;
    _isFavorite = false;
    notifyListeners();
  }


  MangaDetail _buildUpdatedDetail(List<Chapter> chapters) {
    return MangaDetail(
      id: manga.id,
      malId: manga.malId,
      anilistId: manga.anilistId,
      mangaUpdateId: manga.mangaUpdateId,
      title: manga.title,
      author: manga.author,
      type: manga.type,
      genres: manga.genres,
      categories: manga.categories,
      description: manga.description,
      imageUrl: manga.imageUrl,
      localImageUrl: manga.localImageUrl,
      rating: manga.rating,
      popularity: manga.popularity,
      members: manga.members,
      totalView: manga.totalView,
      status: manga.status,
      releaseDate: manga.releaseDate,
      createdAt: manga.createdAt,
      updatedAt: DateTime.now(),
      url: manga.url,
      chapters: chapters,
    );
  }
}
