import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_manga_reader/core/constants/app_colors.dart';
import 'package:my_manga_reader/core/di/injection.dart';
import 'package:my_manga_reader/data/services/manga_api_service.dart';
import 'package:my_manga_reader/routes/app_pages.dart';
import 'package:my_manga_reader/data/models/search_result.dart';
import 'dart:async';
import 'package:dio/dio.dart';

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
        page: _currentPage,
        provider: _selectedProviderName, // ✅ FIX pakai providerName
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

        // Page size logic berdasarkan providerName
        final pageSize = _selectedProviderName.toLowerCase() == 'kiryuu'
            ? 24
            : 10;

        _hasMoreResults = results.length >= pageSize;
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

  Future<void> _performFilteredSearch({
    String? keyword,
    List<String>? genres,
    String? status,
    String? type,
  }) async {
    setState(() {
      _isLoadingSearch = true;
      _error = null;
      _currentPage = 1;
      _hasMoreResults = true;
      _searchResults = [];
    });

    try {
      final results = await _apiService.searchScrapSource(
        keyword: keyword ?? _searchQuery,
        genres: genres,
        status: status,
        type: type,
        page: _currentPage,
        provider: _selectedProviderName,
      );

      if (mounted) {
        setState(() {
          _searchResults = results
              .map((item) => SearchResult.fromJson(item))
              .toList();
          _isLoadingSearch = false;

          // Set page size based on provider
          final pageSize = _selectedProviderName.toLowerCase() == 'kiryuu'
              ? 24
              : 10;
          // Only set hasMoreResults to false if we got fewer results than page size
          // This indicates we've reached the last page
          if (results.length < pageSize) {
            _hasMoreResults = false;
          } else {
            _hasMoreResults = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingSearch = false;
        });
      }
    }
  }

  Future<void> _scrapManga(String mangaUrl) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      await _apiService.scrapManga(mangaUrl, false, _selectedProviderName);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Scraping added to queue!')));
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to scrap: $e')));
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
                _performFilteredSearch(
                  genres: selectedGenres.isEmpty ? null : selectedGenres,
                  type: selectedTypes.isEmpty ? null : selectedTypes.first,
                  status: selectedStatus,
                );
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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Search Manga',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.search, color: Colors.grey),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search titles, authors, or genres...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 14),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _selectedProviderName,
                  isExpanded: true,
                  underline: Container(),
                  items: _providers.map((provider) {
                    return DropdownMenuItem<String>(
                      value: provider['providerName'],
                      child: Text(
                        provider['providerName'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProviderName = value!;
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
                  style: const TextStyle(
                    color: Colors.grey,
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),

          // Search Results
          Expanded(
            child:
                _searchResults.isEmpty &&
                    !_isLoadingSearch &&
                    _searchQuery.isEmpty
                ? const Center(
                    child: Text(
                      'Search for manga to get started',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
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
            return _buildResultCard(item);
          } else {
            // Loading indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildResultCard(SearchResult item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _scrapManga(item.detailUrl),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.thumbnail.isNotEmpty
                    ? Image.network(
                        item.thumbnail,
                        width: 80,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 110,
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 110,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),

              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.type,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.genre,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    if (item.lastUpdateText.isNotEmpty)
                      Text(
                        item.lastUpdateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.brown,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ch. ${item.latestChapterNumber.toInt()}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.latestScrapped != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Updated',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Button
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: item.detailUrl.isNotEmpty
                        ? () => _scrapManga(item.detailUrl)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('SCRAP', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
