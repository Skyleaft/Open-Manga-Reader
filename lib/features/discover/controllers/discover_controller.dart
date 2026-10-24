import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/di/injection.dart';
import '../../../core/models/manga_summary.dart';
import '../../../core/models/paged_response.dart';
import '../../../core/network/manga_api_service.dart';
import '../models/query_paged_manga_request.dart';

class DiscoverController extends ChangeNotifier {
  final MangaApiService _apiService;

  List<MangaSummary> _items = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  String? _searchQuery;
  bool _isSemanticSearch = false;
  String? _errorMessage;
  bool _isGridView = true;

  MangaAdvancedFilter _filter = const MangaAdvancedFilter();
  late MangaSortOption _sortOption;
  CancelToken? _cancelToken;
  Timer? _debounceTimer;
  int _requestCounter = 0;
  bool _disposed = false;

  List<MangaSummary> get items => _items;
  bool get isLoading => _isLoading;
  bool get isMoreLoading => _isMoreLoading;
  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;
  String? get searchQuery => _searchQuery;
  bool get isSemanticSearch => _isSemanticSearch;
  String? get errorMessage => _errorMessage;
  bool get isGridView => _isGridView;
  MangaAdvancedFilter get filter => _filter;
  MangaSortOption get sortOption => _sortOption;
  bool get hasActiveFilters => _filter.hasActiveFilters;

  DiscoverController({
    MangaApiService? apiService,
    String? initialSearch,
    String? initialSortBy,
  }) : _apiService = apiService ?? getIt<MangaApiService>() {
    _searchQuery = initialSearch;
    _sortOption = MangaSortOption(
      field: initialSortBy ?? 'updatedAt',
      direction: 'desc',
    );
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    _safeNotifyListeners();
  }

  Future<void> fetchData({bool refresh = false}) async {
    if (refresh) {
      _debounceTimer?.cancel();
      _cancelToken?.cancel('Refresh requested');
      _cancelToken = CancelToken();
      _currentPage = 1;
      _items = [];
      _hasMore = true;
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();
    } else if (!_hasMore || _isMoreLoading || _isLoading) {
      return;
    } else {
      _isMoreLoading = true;
      _safeNotifyListeners();
    }

    final currentRequest = ++_requestCounter;

    try {
      final PagedResponse<MangaSummary> response;
      if (_isSemanticSearch && _searchQuery != null && _searchQuery!.trim().isNotEmpty) {
        final semanticItems = await _apiService.searchSemantic(
          _searchQuery!,
          limit: 30,
          cancelToken: _cancelToken,
        );
        response = PagedResponse<MangaSummary>(
          items: semanticItems,
          page: 1,
          pageSize: 30,
          totalCount: semanticItems.length,
          totalPages: 1,
          hasPreviousPage: false,
          hasNextPage: false,
        );
      } else {
        final request = QueryPagedMangaRequest(
          filter: _filter.copyWith(
            search: _searchQuery,
            clearSearch: _searchQuery == null || _searchQuery!.trim().isEmpty,
          ),
          sorts: [_sortOption],
          page: _currentPage,
          pageSize: _pageSize,
        );
        response = await _apiService.queryPagedManga(
          request,
          cancelToken: _cancelToken,
        );
      }

      if (currentRequest != _requestCounter || _disposed) return;

      if (refresh) {
        _items = List.from(response.items);
      } else {
        _items.addAll(response.items);
      }

      _isLoading = false;
      _isMoreLoading = false;
      _hasMore = _items.length < response.totalCount &&
          !_isSemanticSearch &&
          response.items.isNotEmpty;
      if (_hasMore) _currentPage++;
      _safeNotifyListeners();
    } catch (e) {
      if (currentRequest != _requestCounter || _disposed) return;
      if (e is DioException && CancelToken.isCancel(e)) return;

      _isLoading = false;
      _isMoreLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
    }
  }

  void onSearchChanged(String value) {
    final newQuery = value.trim().isEmpty ? null : value.trim();
    if (_searchQuery == newQuery) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (_disposed) return;
      _searchQuery = newQuery;
      fetchData(refresh: true);
    });
  }

  void setSemanticSearch(bool value) {
    if (_isSemanticSearch == value) return;
    _isSemanticSearch = value;
    fetchData(refresh: true);
  }

  void applyFilterAndSort(MangaAdvancedFilter newFilter, MangaSortOption newSort) {
    _filter = newFilter;
    _sortOption = newSort;
    fetchData(refresh: true);
  }

  void updateParamsIfChanged({String? initialSearch, String? sortBy}) {
    final sortField = sortBy ?? 'updatedAt';
    if (_searchQuery != initialSearch || _sortOption.field != sortField) {
      _searchQuery = initialSearch;
      _sortOption = MangaSortOption(
        field: sortField,
        direction: 'desc',
      );
      fetchData(refresh: true);
    }
  }

  void clearAllFilters() {
    _filter = const MangaAdvancedFilter(nsfw: false);
    _searchQuery = null;
    fetchData(refresh: true);
  }

  void removeIncludedGenre(String genre) {
    final list = List<String>.from(_filter.includedGenres)..remove(genre);
    _filter = _filter.copyWith(includedGenres: list);
    fetchData(refresh: true);
  }

  void removeExcludedGenre(String genre) {
    final list = List<String>.from(_filter.excludedGenres)..remove(genre);
    _filter = _filter.copyWith(excludedGenres: list);
    fetchData(refresh: true);
  }

  void removeType(String type) {
    final list = List<String>.from(_filter.types)..remove(type);
    _filter = _filter.copyWith(types: list);
    fetchData(refresh: true);
  }

  void removeStatus(String status) {
    final list = List<String>.from(_filter.statuses)..remove(status);
    _filter = _filter.copyWith(statuses: list);
    fetchData(refresh: true);
  }

  void clearAuthor() {
    _filter = _filter.copyWith(clearAuthor: true);
    fetchData(refresh: true);
  }

  void clearMinRating() {
    _filter = _filter.copyWith(clearMinRating: true);
    fetchData(refresh: true);
  }

  void clearMinChapters() {
    _filter = _filter.copyWith(clearMinChapters: true);
    fetchData(refresh: true);
  }

  void resetNsfw() {
    _filter = _filter.copyWith(nsfw: false);
    fetchData(refresh: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _cancelToken?.cancel('Controller disposed');
    super.dispose();
  }
}
