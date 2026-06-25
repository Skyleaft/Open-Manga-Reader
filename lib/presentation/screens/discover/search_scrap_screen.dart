import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_manga_reader/core/constants/app_colors.dart';
import 'package:my_manga_reader/core/widgets/alert_banner.dart';
import 'package:my_manga_reader/core/di/injection.dart';
import 'package:my_manga_reader/data/services/manga_api_service.dart';
import 'package:my_manga_reader/routes/app_pages.dart';
import 'package:my_manga_reader/data/models/search_result.dart';
import 'package:my_manga_reader/data/models/manga_detail.dart';
import 'package:my_manga_reader/data/models/manga_summary.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'widgets/search_scrap_card.dart';

class SearchScrapScreen extends StatefulWidget {
  const SearchScrapScreen({super.key});

  @override
  State<SearchScrapScreen> createState() => _SearchScrapScreenState();
}

class _SearchScrapScreenState extends State<SearchScrapScreen> {
  final _searchController = TextEditingController();
  final _apiService = getIt<MangaApiService>();

  bool _isLoadingSearch = false;
  bool _isLoadingProviders = false;
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
    setState(() => _isLoadingProviders = true);

    try {
      final response = await _apiService.getScrapProviders();
      _providers = response;

      if (_providers.isNotEmpty) {
        _selectedProviderName = _providers[0]['providerName'];
      }
    } catch (e) {
      _providers = [
        {'providerName': 'Komiku'},
        {'providerName': 'Kiryuu'},
      ];

      _selectedProviderName = 'Komiku';
    }

    setState(() => _isLoadingProviders = false);

    // Auto load first page
    _performSearch();
  }

  void _onSearchChanged() {
    // Only update search query, don't perform search
    _searchQuery = _searchController.text;
  }

  Future<void> _performSearch() async {
    final query = _searchQuery.trim();
    final currentRequestCounter = ++_searchRequestCounter;

    // Cancel any ongoing search request
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

      // Check if this request is still the latest one
      if (currentRequestCounter != _searchRequestCounter) {
        return; // Ignore results from cancelled request
      }

      if (!mounted) return;

      setState(() {
        if (_currentPage == 1) {
          _searchResults = results
              .map((e) => SearchResult.fromJson(e))
              .toList();
        } else {
          _searchResults.addAll(
            results.map((e) => SearchResult.fromJson(e)).toList(),
          );
        }

        _isLoadingSearch = false;

        _hasMoreResults = results.isNotEmpty;
      });
    } catch (e) {
      // Check if this request was cancelled
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return; // Ignore cancelled request
      }

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
          child: _ScrapMangaModal(
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
        builder: (_) => const Center(
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

      Navigator.pop(context); // pop loading dialog

      AlertBanner.show(
        context,
        scrapChapters
            ? 'Added to queue: Scraping all chapters...'
            : 'Added to queue: Scraping metadata...',
        type: AlertBannerType.success,
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context); // pop loading dialog

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
    final genres = await _apiService.getAllGenres();
    final types = await _apiService.getAllTypes();

    final selectedGenres = <String>[];
    final selectedTypes = <String>[];
    String? selectedStatus;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Genres
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
                      label: Text(genre),
                      selected: selectedGenres.contains(genre),
                      onSelected: (bool selected) {
                        setState(() {
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

                // Types
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
                      label: Text(type),
                      selected: selectedTypes.contains(type),
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
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

                // Status
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Ongoing'),
                        value: 'ongoing',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Completed'),
                        value: 'completed',
                        groupValue: selectedStatus,
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value;
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                _selectedGenres = selectedGenres.isEmpty
                    ? null
                    : List.from(selectedGenres);
                _selectedType = selectedTypes.isEmpty
                    ? null
                    : selectedTypes.first;
                _selectedStatus = selectedStatus;

                _currentPage = 1;
                _hasMoreResults = true;

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
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

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
          IconButton(
            icon: Icon(Icons.tune, color: textColor),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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
                      ),
                      style: TextStyle(fontSize: 14, color: textColor),
                      onSubmitted: (value) {
                        // Trigger search when Enter is pressed
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

          // Provider Selector
          if (_providers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  underline: Container(),
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor, fontSize: 14),
                  items: _providers.map((provider) {
                    return DropdownMenuItem<String>(
                      value: provider['providerName'],
                      child: Text(
                        provider['providerName'],
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProviderName = value!;
                      _selectedGenres = null;
                      _selectedStatus = null;
                      _selectedType = null;
                      _currentPage = 1;
                      _hasMoreResults = true;
                      _searchResults = [];
                    });

                    _performSearch(); // ✅ dipanggil di luar setState
                  },
                ),
              ),
            ),

          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Search Results (${_searchResults.length})'
                      : 'Search Results (0)',
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
                      color: AppColors.primary.withOpacity(0.1),
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

          // Error Message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.red.withOpacity(0.2)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),

          // Search Results
          Expanded(
            child:
                _searchResults.isEmpty &&
                    !_isLoadingSearch &&
                    _searchQuery.isEmpty
                ? Center(
                    child: Text(
                      'Search for manga to get started',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey,
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
          // Check if we're near the bottom (within 100 pixels) and there are more results
          if (metrics.pixels >= metrics.maxScrollExtent - 100 &&
              _hasMoreResults &&
              !_isLoadingSearch) {
            _loadMore();
          }
        }
        return false;
      },
      child: ListView.builder(
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
            // Loading indicator at the bottom
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

class _ScrapMangaModal extends StatefulWidget {
  final SearchResult item;
  final String provider;
  final MangaApiService apiService;
  final Function(bool scrapChapters, String? linkId) onScrap;

  const _ScrapMangaModal({
    required this.item,
    required this.provider,
    required this.apiService,
    required this.onScrap,
  });

  @override
  State<_ScrapMangaModal> createState() => _ScrapMangaModalState();
}

class _ScrapMangaModalState extends State<_ScrapMangaModal> {
  bool _isLoadingDetail = true;
  MangaDetail? _detail;
  String? _error;

  bool _isSearchingExisting = false;
  List<MangaSummary> _existingMangaResults = [];
  MangaSummary? _selectedExistingManga;
  final _existingSearchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _existingSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _error = null;
    });

    try {
      final data = await widget.apiService.getScrapMangaDetail(
        provider: widget.provider,
        mangaUrl: widget.item.detailUrl,
      );
      if (mounted) {
        setState(() {
          _detail = MangaDetail.fromMap(data);
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  void _searchExistingManga(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _existingMangaResults = [];
        _isSearchingExisting = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isSearchingExisting = true);
      try {
        final response = await widget.apiService.getPagedManga(
          search: query,
          pageSize: 10,
        );
        if (mounted) {
          setState(() {
            _existingMangaResults = response.items;
            _isSearchingExisting = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearchingExisting = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.primary;

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.all(16.0),
      child: _isLoadingDetail
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Failed to load manga details: $_error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchDetail,
                  child: const Text('Retry'),
                ),
              ],
            )
          : _buildDetailContent(isDark, textColor),
    );
  }

  Widget _buildDetailContent(bool isDark, Color textColor) {
    final detail = _detail!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.displayImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.apiService.getImageUrl(detail.displayImageUrl),
                    width: 90,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 120,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Author: ${detail.author}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type: ${detail.type} | Status: ${detail.status ?? "Unknown"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (detail.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            detail.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (detail.genres != null && detail.genres!.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detail.genres!.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              detail.description!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Total Chapters: ${detail.chapters.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: detail.chapters.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No chapters found'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: detail.chapters.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ch = detail.chapters[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          ch.title,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          'Number: ${ch.chapterNumber}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: ch.language.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ch.language.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Link to Existing Manga (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (_selectedExistingManga == null) ...[
            TextField(
              controller: _existingSearchController,
              decoration: InputDecoration(
                hintText: 'Search local manga to link...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _isSearchingExisting
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: _searchExistingManga,
            ),
            if (_existingMangaResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _existingMangaResults.length,
                  itemBuilder: (context, index) {
                    final ex = _existingMangaResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(ex.title),
                      subtitle: Text(ex.author),
                      onTap: () {
                        setState(() {
                          _selectedExistingManga = ex;
                          _existingMangaResults = [];
                          _existingSearchController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedExistingManga!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${_selectedExistingManga!.id}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedExistingManga = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScrap(false, _selectedExistingManga?.id);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Scrap Metadata'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    foregroundColor: Colors.orange,
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScrap(true, _selectedExistingManga?.id);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Scrap Chapters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
