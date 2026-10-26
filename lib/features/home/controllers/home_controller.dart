import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/models/manga_summary.dart';
import '../../../core/network/manga_api_service.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../models/trending_tab.dart';

class HomeController extends ChangeNotifier {
  final MangaApiService _apiService;
  final ProgressionService _progressionService;
  final MangaDetailService _detailService;

  bool _disposed = false;

  final Map<int, List<MangaSummary>> _trendingByTab = {};
  final Map<int, bool> _trendingLoadingByTab = {};

  List<MangaSummary> _latestUpdates = [];
  List<MangaSummary> _recommendedManga = [];
  List<MangaSummary> _topManga = [];

  List<MangaProgression> _recentProgressions = [];
  Map<String, MangaDetail> _historyDetailsMap = {};
  bool _isLoadingHistory = true;

  bool _isLoadingLatest = true;
  bool _isLoadingRecommended = true;
  bool _isLoadingTop = true;

  Map<int, List<MangaSummary>> get trendingByTab => _trendingByTab;
  Map<int, bool> get trendingLoadingByTab => _trendingLoadingByTab;
  List<MangaSummary> get latestUpdates => _latestUpdates;
  List<MangaSummary> get recommendedManga => _recommendedManga;
  List<MangaSummary> get topManga => _topManga;
  List<MangaProgression> get recentProgressions => _recentProgressions;
  Map<String, MangaDetail> get historyDetailsMap => _historyDetailsMap;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingLatest => _isLoadingLatest;
  bool get isLoadingRecommended => _isLoadingRecommended;
  bool get isLoadingTop => _isLoadingTop;

  List<MangaSummary> get heroManga {
    final trending = _trendingByTab[0];
    if (trending != null && trending.isNotEmpty) {
      return trending.take(5).toList();
    }
    if (_topManga.isNotEmpty) {
      return _topManga.take(5).toList();
    }
    return [];
  }

  bool get isLoadingHero =>
      (_trendingLoadingByTab[0] ?? true) && _isLoadingTop && heroManga.isEmpty;

  HomeController({
    MangaApiService? apiService,
    ProgressionService? progressionService,
    MangaDetailService? detailService,
  }) : _apiService = apiService ?? getIt<MangaApiService>(),
       _progressionService = progressionService ?? getIt<ProgressionService>(),
       _detailService = detailService ?? getIt<MangaDetailService>() {
    _progressionService.addListener(_onProgressionServiceChanged);
  }

  void _onProgressionServiceChanged() {
    if (!_disposed) {
      fetchHistory();
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _progressionService.removeListener(_onProgressionServiceChanged);
    super.dispose();
  }

  Future<void> fetchAllData({bool syncProgressionFirst = true}) async {
    if (syncProgressionFirst) {
      // 1. Fetch & sync progression first so continue reading and recommendations reflect latest state from other devices
      try {
        await fetchHistory(forceSync: true);
      } catch (e) {
        debugPrint('Error syncing/fetching history first: $e');
      }
    }

    // 2. Fetch other sections in parallel
    await Future.wait([
      if (!syncProgressionFirst)
        fetchHistory().catchError(
          (e) => debugPrint('Error fetching history: $e'),
        ),
      fetchTrendingForTab(
        0,
      ).catchError((e) => debugPrint('Error fetching trending: $e')),
      fetchLatest().catchError((e) => debugPrint('Error fetching latest: $e')),
      fetchTop()
          .then((_) => fetchRecommended())
          .catchError((e) => debugPrint('Error fetching top/recommended: $e')),
    ]);
  }

  Future<void> refresh() async {
    _trendingByTab.clear();
    _trendingLoadingByTab.clear();
    _isLoadingHistory = true;
    _isLoadingLatest = true;
    _isLoadingRecommended = true;
    _isLoadingTop = true;
    _safeNotifyListeners();
    await fetchAllData(syncProgressionFirst: true);
  }

  Future<void> fetchTrendingForTab(int tabIdx) async {
    if (_trendingLoadingByTab[tabIdx] == true) return;
    _trendingLoadingByTab[tabIdx] = true;
    _safeNotifyListeners();

    try {
      final tab = kTrendingTabs[tabIdx];
      final response = await _apiService.getTrending(
        genres: tab.genre != null ? [tab.genre!] : null,
        pageSize: 10,
      );
      _trendingByTab[tabIdx] = response.items;
    } catch (e) {
      debugPrint('fetchTrendingForTab error: $e');
    } finally {
      _trendingLoadingByTab[tabIdx] = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchHistory({bool forceSync = false}) async {
    _isLoadingHistory = true;
    _safeNotifyListeners();

    try {
      // Preload local cache first so UI immediately shows cached items while syncing
      if (forceSync && _recentProgressions.isEmpty) {
        final initialLocal = await _progressionService.getAllProgressions(forceSync: false);
        if (initialLocal.isNotEmpty && _recentProgressions.isEmpty) {
          initialLocal.sort((a, b) => b.lastRead.compareTo(a.lastRead));
          _recentProgressions = initialLocal.take(10).toList();
          _safeNotifyListeners();
        }
      }

      final progressions = await _progressionService.getAllProgressions(
        forceSync: forceSync,
      );
      progressions.sort((a, b) => b.lastRead.compareTo(a.lastRead));
      final recent = progressions.take(10).toList();

      final results = await Future.wait(
        recent.map((p) async {
          if (p.manga != null) {
            return MapEntry(p.mangaId, MangaDetail.fromMangaSummary(p.manga!));
          }

          if (_historyDetailsMap.containsKey(p.mangaId)) {
            return MapEntry(p.mangaId, _historyDetailsMap[p.mangaId]!);
          }

          try {
            final cached = await _detailService.getDetail(p.mangaId);
            if (cached != null) {
              return MapEntry(p.mangaId, cached);
            } else {
              final data = await _apiService.getMangaDetail(p.mangaId);
              final detail = MangaDetail.fromMap(data);
              await _detailService.saveDetail(detail);
              return MapEntry(p.mangaId, detail);
            }
          } catch (_) {
            return null;
          }
        }),
      );

      final detailsMap = <String, MangaDetail>{};
      for (final entry in results) {
        if (entry != null) {
          detailsMap[entry.key] = entry.value;
        }
      }

      _recentProgressions = recent;
      _historyDetailsMap = detailsMap;
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    } finally {
      _isLoadingHistory = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchLatest() async {
    try {
      final response = await _apiService.getPagedManga(
        sortBy: 'updatedAt',
        orderBy: 'desc',
        pageSize: 5,
      );
      _latestUpdates = response.items;
    } catch (_) {
    } finally {
      _isLoadingLatest = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchTop() async {
    try {
      final response = await _apiService.getPagedManga(
        sortBy: 'rating',
        orderBy: 'desc',
        pageSize: 15,
      );
      _topManga = response.items;
    } catch (_) {
    } finally {
      _isLoadingTop = false;
      _safeNotifyListeners();
    }
  }

  Future<void> fetchRecommended() async {
    try {
      List<String> ids;
      if (_recentProgressions.isNotEmpty) {
        ids = _recentProgressions.take(5).map((e) => e.mangaId).toList();
      } else {
        final history = await _progressionService.getAllProgressions();
        history.sort((a, b) => b.lastRead.compareTo(a.lastRead));
        ids = history.take(5).map((e) => e.mangaId).toList();
      }

      if (ids.isEmpty && _topManga.isNotEmpty) {
        ids = [_topManga.first.id];
      }

      final items = await _apiService.getRecommendations(
        readingHistoryIds: ids,
        limit: 6,
      );
      _recommendedManga = items;
    } catch (_) {
    } finally {
      _isLoadingRecommended = false;
      _safeNotifyListeners();
    }
  }
}
