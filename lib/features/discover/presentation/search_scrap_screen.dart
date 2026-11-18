import 'dart:async';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../models/search_result.dart';
import 'widgets/search_scrap_card.dart';
import 'widgets/scrap_manga_modal.dart';

class SearchScrapScreen extends StatefulWidget {
  const SearchScrapScreen({super.key});

  @override
  State<SearchScrapScreen> createState() => _SearchScrapScreenState();
}

class _SearchScrapScreenState extends State<SearchScrapScreen> {
  final _searchController = TextEditingController();
  final _apiService = getIt<MangaApiService>();

  bool _isLoadingSearch = false;
  List<SearchResult> _searchResults = [];
  List<Map<String, dynamic>> _providers = [];
  List<String>? _selectedGenres;
  String? _selectedStatus;
  String? _selectedType;
  String? _error;

  String _selectedProviderName = '';
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasMoreResults = true;

  Timer? _debounceTimer;
  CancelToken? _searchCancelToken;
  int _searchRequestCounter = 0;

  // Cached filter lists to avoid repeated network roundtrips
  List<String>? _cachedGenres;
  List<String>? _cachedTypes;

  @override
  void initState() {
    super.initState();
    _loadProviders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCancelToken?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final response = await _apiService.getScrapProviders();
      _providers = response;

      if (_providers.isNotEmpty) {
        _selectedProviderName = _providers[0]['providerName'];
      }
    } catch (_) {
      _providers = [
        {'providerName': 'Komiku'},
        {'providerName': 'Kiryuu'},
      ];
      _selectedProviderName = 'Komiku';
    }

    if (mounted) setState(() {});
    _performSearch();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (_searchQuery == query) return;
    _searchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _currentPage = 1;
      _hasMoreResults = true;
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchQuery.trim();
    final currentRequestCounter = ++_searchRequestCounter;

    _searchCancelToken?.cancel();
    _searchCancelToken = CancelToken();

    setState(() {
      _isLoadingSearch = true;
      _error = null;

      if (_currentPage == 1) {
        _searchResults = [];
      }
    });

    try {
      final results = await _apiService.searchScrapSource(
        keyword: query,
        genres: _selectedGenres,
        status: _selectedStatus,
        type: _selectedType,
        page: _currentPage,
        provider: _selectedProviderName,
      );

      if (currentRequestCounter != _searchRequestCounter) return;
      if (!mounted) return;

      setState(() {
        final newItems = results.map((e) => SearchResult.fromJson(e)).toList();
        if (_currentPage == 1) {
          _searchResults = newItems;
        } else {
          _searchResults.addAll(newItems);
        }

        _isLoadingSearch = false;
        _hasMoreResults = newItems.isNotEmpty;
      });
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }

      if (currentRequestCounter != _searchRequestCounter) return;
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoadingSearch = false;
      });
    }
  }

  void _showScrapModal(SearchResult item) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          child: ScrapMangaModal(
            item: item,
            provider: _selectedProviderName,
            apiService: _apiService,
            onScrap: (scrapChapters, linkId) {
              _executeScrap(item.detailUrl, scrapChapters, linkId: linkId);
            },
          ),
        );
      },
    );
  }

  Future<void> _executeScrap(
    String mangaUrl,
    bool scrapChapters, {
    String? linkId,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      await _apiService.scrapManga(
        mangaUrl,
        scrapChapters,
        _selectedProviderName,
        linkId: linkId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      AlertBanner.show(
        context,
        scrapChapters
            ? 'Added to queue: Scraping all chapters...'
            : 'Added to queue: Scraping metadata...',
        type: AlertBannerType.success,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      AlertBanner.show(
        context,
        'Failed to scrap: $e',
        type: AlertBannerType.error,
      );
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingSearch || !_hasMoreResults) return;

    _currentPage++;
    await _performSearch();
  }

  Future<void> _showFilterDialog() async {
    List<String> genres = _cachedGenres ?? [];
    List<String> types = _cachedTypes ?? [];

    if (genres.isEmpty || types.isEmpty) {
      try {
        final fetchedGenres = await _apiService.getAllGenres();
        final fetchedTypes = await _apiService.getAllTypes();
        _cachedGenres = fetchedGenres;
        _cachedTypes = fetchedTypes;
        genres = fetchedGenres;
        types = fetchedTypes;
      } catch (_) {}
    }

    if (!mounted) return;

    final selectedGenres = List<String>.from(_selectedGenres ?? []);
    final selectedTypes = _selectedType != null ? [_selectedType!] : <String>[];
    String? selectedStatus = _selectedStatus;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Source Results'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (genres.isNotEmpty) ...[
                  const Text(
                    'Genres',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: genres.map((genre) {
                      return FilterChip(
                        label: Text(genre, style: const TextStyle(fontSize: 12)),
                        selected: selectedGenres.contains(genre),
                        onSelected: (bool selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedGenres.add(genre);
                            } else {
                              selectedGenres.remove(genre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (types.isNotEmpty) ...[
                  const Text(
                    'Types',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: types.map((type) {
                      return FilterChip(
                        label: Text(type, style: const TextStyle(fontSize: 12)),
                        selected: selectedTypes.contains(type),
                        onSelected: (bool selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedTypes.clear();
                              selectedTypes.add(type);
                            } else {
                              selectedTypes.remove(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Ongoing'),
                        selected: selectedStatus?.toLowerCase() == 'ongoing',
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = selected ? 'ongoing' : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Completed'),
                        selected: selectedStatus?.toLowerCase() == 'completed',
                        onSelected: (selected) {
                          setDialogState(() {
                            selectedStatus = selected ? 'completed' : null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  selectedGenres.clear();
                  selectedTypes.clear();
                  selectedStatus = null;
                });
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedGenres =
                      selectedGenres.isEmpty ? null : List.from(selectedGenres);
                  _selectedType =
                      selectedTypes.isEmpty ? null : selectedTypes.first;
                  _selectedStatus = selectedStatus;
                  _currentPage = 1;
                  _hasMoreResults = true;
                });
                _performSearch();
              },
              child: const Text('Apply Filter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final textColor = isDarkMode ? Colors.white : AppColors.primary;
    final cardColor = isDarkMode ? AppColors.cardDark : Colors.white;
    final shadowColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.08);

    final hasActiveFilters =
        (_selectedGenres != null && _selectedGenres!.isNotEmpty) ||
        _selectedType != null ||
        _selectedStatus != null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Search From Source',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.tune, color: textColor),
                onPressed: _showFilterDialog,
              ),
              if (hasActiveFilters)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.search,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search titles, authors, or genres...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        isDense: true,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _currentPage = 1;
                                  _performSearch();
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(fontSize: 14, color: textColor),
                      onSubmitted: (value) {
                        _searchQuery = value.trim();
                        _currentPage = 1;
                        _hasMoreResults = true;
                        _performSearch();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_providers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _selectedProviderName,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor, fontSize: 14),
                  items: _providers.map((provider) {
                    return DropdownMenuItem<String>(
                      value: provider['providerName'],
                      child: Text(
                        'Provider: ${provider['providerName']}',
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null || value == _selectedProviderName) return;
                    setState(() {
                      _selectedProviderName = value;
                      _selectedGenres = null;
                      _selectedStatus = null;
                      _selectedType = null;
                      _currentPage = 1;
                      _hasMoreResults = true;
                      _searchResults = [];
                    });
                    _performSearch();
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Search Results (${_searchResults.length})'
                      : 'Search Results (${_searchResults.length})',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_providers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _selectedProviderName,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.red.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _performSearch,
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _searchResults.isEmpty && !_isLoadingSearch
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.manage_search_rounded,
                            size: 56,
                            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Search for manga from source'
                                : 'No manga found on $_selectedProviderName',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Type a title or author to browse online scrap sources.'
                                : 'Try searching another keyword or switch providers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 150 &&
              _hasMoreResults &&
              !_isLoadingSearch) {
            _loadMore();
          }
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _searchResults.length + (_isLoadingSearch ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _searchResults.length) {
            final item = _searchResults[index];
            return SearchScrapCard(
              item: item,
              isDarkMode: isDarkMode,
              onScrap: () => _showScrapModal(item),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
        },
      ),
    );
  }
}
