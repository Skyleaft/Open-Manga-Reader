import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../models/library_manga.dart';
import '../services/library_service.dart';
import '../../history/services/progression_service.dart';

enum LibrarySortOption {
  lastUpdated,
  alphabetical,
  progress,
  dateAdded,
}

class LibraryController extends ChangeNotifier {
  final LibraryService _libraryService;
  final MangaDetailService _detailService;
  final ProgressionService _progressionService;
  bool _disposed = false;

  List<LibraryManga> _libraryMangas = [];
  Map<String, MangaDetail> _cachedDetails = {};
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';
  bool _showFavoritesOnly = false;
  bool _isGridView = false;
  LibrarySortOption _sortOption = LibrarySortOption.lastUpdated;

  List<LibraryManga> get libraryMangas => _libraryMangas;
  Map<String, MangaDetail> get cachedDetails => _cachedDetails;
  bool get isLoading => _isLoading;
  String get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;
  bool get showFavoritesOnly => _showFavoritesOnly;
  bool get isGridView => _isGridView;
  LibrarySortOption get sortOption => _sortOption;

  LibraryController({
    LibraryService? libraryService,
    MangaDetailService? detailService,
    ProgressionService? progressionService,
  })  : _libraryService = libraryService ?? getIt<LibraryService>(),
        _detailService = detailService ?? getIt<MangaDetailService>(),
        _progressionService = progressionService ?? getIt<ProgressionService>() {
    _progressionService.addListener(_onProgressionChanged);
  }

  void _onProgressionChanged() {
    if (!_disposed) {
      loadLibrary(forceSync: false);
    }
  }

  Map<String, int> get statusCounts {
    final counts = <String, int>{
      'All': _libraryMangas.length,
      'Reading': 0,
      'Completed': 0,
      'OnHold': 0,
      'Dropped': 0,
      'PlanToRead': 0,
    };

    for (final m in _libraryMangas) {
      final key = m.status;
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<LibraryManga> get filteredMangas {
    final list = _libraryMangas.where((m) {
      final matchesStatus = _selectedStatus == 'All' ||
          m.status.toLowerCase() == _selectedStatus.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFav = !_showFavoritesOnly || m.isFavorite;

      return matchesStatus && matchesSearch && matchesFav;
    }).toList();

    // Apply Sorting
    switch (_sortOption) {
      case LibrarySortOption.lastUpdated:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case LibrarySortOption.alphabetical:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySortOption.progress:
        list.sort((a, b) => b.currentChapter.compareTo(a.currentChapter));
        break;
      case LibrarySortOption.dateAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
    }

    return list;
  }

  void setSelectedStatus(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void setSortOption(LibrarySortOption sort) {
    _sortOption = sort;
    notifyListeners();
  }

  Future<void> updateMangaStatus(String mangaId, String newStatus) async {
    await _libraryService.updateStatus(mangaId, newStatus);
    final index = _libraryMangas.indexWhere((m) => m.id == mangaId);
    if (index >= 0) {
      _libraryMangas[index] = _libraryMangas[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  Future<void> toggleMangaFavorite(String mangaId) async {
    await _libraryService.toggleFavorite(mangaId);
    final index = _libraryMangas.indexWhere((m) => m.id == mangaId);
    if (index >= 0) {
      _libraryMangas[index] = _libraryMangas[index].copyWith(
        isFavorite: !_libraryMangas[index].isFavorite,
      );
      notifyListeners();
    }
  }

  Future<void> removeManga(String mangaId) async {
    await _libraryService.removeFromLibrary(mangaId);
    _libraryMangas.removeWhere((m) => m.id == mangaId);
    _cachedDetails.remove(mangaId);
    notifyListeners();
  }

  Future<void> loadLibrary({bool forceSync = false}) async {
    try {
      final list = await _libraryService.getAllLibraryMangas(forceSync: forceSync);
      final Map<String, MangaDetail> details = {};
      for (final manga in list) {
        final detail = await _detailService.getDetail(manga.id);
        if (detail != null) {
          details[manga.id] = detail;
        }
      }
      _libraryMangas = list;
      _cachedDetails = details;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _libraryService.refreshFromApi();
    await loadLibrary();
  }

  @override
  void dispose() {
    _disposed = true;
    _progressionService.removeListener(_onProgressionChanged);
    super.dispose();
  }
}
