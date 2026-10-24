import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../models/progression.dart';
import '../services/progression_service.dart';

class HistoryController extends ChangeNotifier {
  final ProgressionService _progressionService;
  final MangaApiService _apiService;
  final MangaDetailService _detailService;

  bool _disposed = false;

  List<MangaProgression> _progressions = [];
  Map<String, MangaDetail> _mangaDetailsMap = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  List<MangaProgression> get progressions => _progressions;
  Map<String, MangaDetail> get mangaDetailsMap => _mangaDetailsMap;
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String get searchQuery => _searchQuery;

  HistoryController({
    ProgressionService? progressionService,
    MangaApiService? apiService,
    MangaDetailService? detailService,
  })  : _progressionService = progressionService ?? getIt<ProgressionService>(),
        _apiService = apiService ?? getIt<MangaApiService>(),
        _detailService = detailService ?? getIt<MangaDetailService>() {
    _progressionService.addListener(_onProgressionServiceChanged);
  }

  void _onProgressionServiceChanged() {
    if (!_disposed) {
      _reloadHistoryFromLocalCache();
    }
  }

  Future<void> _reloadHistoryFromLocalCache() async {
    try {
      final list = await _progressionService.getAllProgressions(forceSync: false);
      list.sort((a, b) => b.lastRead.compareTo(a.lastRead));
      _progressions = list;
      await _hydrateMangaDetails(list);
    } catch (e) {
      debugPrint('Error reloading history on progression change: $e');
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

  void setSelectedFilter(String filter) {
    _selectedFilter = filter;
    _safeNotifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _safeNotifyListeners();
  }

  bool _matchesFilter(MangaProgression progression, String filter) {
    if (filter == 'Completed') {
      return progression.isCompleted;
    } else if (filter == 'In Progress') {
      return !progression.isCompleted;
    }

    final localDateTime = progression.lastRead.toLocal();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (filter == 'Today') {
      return localDateTime.isAfter(todayStart) ||
          localDateTime.isAtSameMomentAs(todayStart);
    } else if (filter == 'This Week') {
      final weekday = now.weekday;
      final weekStart = todayStart.subtract(Duration(days: weekday - 1));
      return localDateTime.isAfter(weekStart) ||
          localDateTime.isAtSameMomentAs(weekStart);
    } else if (filter == 'This Month') {
      final monthStart = DateTime(now.year, now.month, 1);
      return localDateTime.isAfter(monthStart) ||
          localDateTime.isAtSameMomentAs(monthStart);
    }
    return true;
  }

  List<MangaProgression> get filteredProgressions {
    return _progressions.where((progression) {
      final matchesStatusOrTime = _matchesFilter(progression, _selectedFilter);
      if (!matchesStatusOrTime) return false;

      if (_searchQuery.isNotEmpty) {
        final detail = _mangaDetailsMap[progression.mangaId];
        final title = (progression.manga?.title ?? detail?.title ?? '')
            .toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query);
      }

      return true;
    }).toList();
  }

  Future<void> loadHistory({bool forceSync = false}) async {
    _isLoading = true;
    _safeNotifyListeners();

    try {
      if (forceSync) {
        await _progressionService.refreshFromApi();
      }
      final list = await _progressionService.getAllProgressions(forceSync: forceSync);
      list.sort((a, b) => b.lastRead.compareTo(a.lastRead));
      _progressions = list;

      await _hydrateMangaDetails(list);
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadHistory(forceSync: true);
  }

  Future<void> _hydrateMangaDetails(List<MangaProgression> list) async {
    final detailsMap = <String, MangaDetail>{};

    final results = await Future.wait(
      list.map((progression) async {
        if (progression.manga != null) {
          final detail = MangaDetail.fromMangaSummary(progression.manga!);
          return MapEntry(progression.mangaId, detail);
        }

        try {
          final cached = await _detailService.getDetail(progression.mangaId);
          if (cached != null) {
            // Background fetch fresh detail
            _apiService.getMangaDetail(progression.mangaId).then((data) {
              final fresh = MangaDetail.fromMap(data);
              _detailService.saveDetail(fresh);
              _mangaDetailsMap[progression.mangaId] = fresh;
              _safeNotifyListeners();
            }).catchError((_) {});
            return MapEntry(progression.mangaId, cached);
          } else {
            final detailData = await _apiService.getMangaDetail(
              progression.mangaId,
            );
            final mangaDetail = MangaDetail.fromMap(detailData);
            await _detailService.saveDetail(mangaDetail);
            return MapEntry(progression.mangaId, mangaDetail);
          }
        } catch (_) {
          return null;
        }
      }),
    );

    for (final entry in results) {
      if (entry != null) {
        detailsMap[entry.key] = entry.value;
      }
    }

    _mangaDetailsMap = detailsMap;
    _safeNotifyListeners();
  }

  Future<void> deleteProgression(String mangaId) async {
    await _progressionService.deleteProgression(mangaId);
    _progressions.removeWhere((p) => p.mangaId == mangaId);
    _mangaDetailsMap.remove(mangaId);
    _safeNotifyListeners();
  }

  Future<void> clearAllHistory() async {
    await _progressionService.clearAllProgressions();
    _progressions.clear();
    _mangaDetailsMap.clear();
    _safeNotifyListeners();
  }
}

