import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/discover_card.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/models/manga_summary.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../routes/app_pages.dart';
import 'widgets/discover_header.dart';
import 'widgets/scrap_queue_dialog.dart';
import 'widgets/filter_dialog.dart';

class DiscoverScreen extends StatefulWidget {
  final String? initialSearch;
  final String? sortBy;

  const DiscoverScreen({super.key, this.initialSearch, this.sortBy});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final List<MangaSummary> _items = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMore = true;
  String? _searchQuery;

  List<String> _selectedGenres = [];
  String? _selectedType;
  String? _selectedStatus;

  late String _sortBy;
  String _orderBy = 'desc';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearch;
    _sortBy = widget.sortBy ?? 'updatedAt';
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != oldWidget.initialSearch ||
        widget.sortBy != oldWidget.sortBy) {
      _searchQuery = widget.initialSearch;
      _sortBy = widget.sortBy ?? 'updatedAt';
      _fetchData(refresh: true);
    }
  }

  Future<void> _fetchData({bool refresh = false}) async {
    if (refresh) {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
        _items.clear();
        _hasMore = true;
        _isLoading = true;
      });
    } else if (!_hasMore || _isMoreLoading) {
      return;
    }

    if (_currentPage > 1) {
      setState(() {
        _isMoreLoading = true;
      });
    }

    try {
      final response = await _apiService.getPagedManga(
        page: _currentPage,
        pageSize: _pageSize,
        search: _searchQuery,
        genres: _selectedGenres.isEmpty ? null : _selectedGenres,
        type: _selectedType,
        status: _selectedStatus,
        sortBy: _sortBy,
        orderBy: _orderBy,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(response.items);
        _isLoading = false;
        _isMoreLoading = false;
        _hasMore = _items.length < response.totalCount;
        if (_hasMore) _currentPage++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isMoreLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _onSearch(String value) {
    final newQuery = value.isEmpty ? null : value;
    if (_searchQuery == newQuery) return;
    _searchQuery = newQuery;
    _fetchData(refresh: true);
  }

  void _onShowQueue() {
    showDialog(
      context: context,
      builder: (context) => const ScrapQueueDialog(),
    );
  }

  void _onSearchScrapSource() {
    Navigator.pushNamed(context, AppRoutes.searchScrap);
  }

  void _onFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterDialog(
        initialGenres: _selectedGenres,
        initialType: _selectedType,
        initialStatus: _selectedStatus,
        initialSortBy: _sortBy,
        initialOrderBy: _orderBy,
        onApply: (genres, type, status, sortBy, orderBy) {
          setState(() {
            _selectedGenres = genres;
            _selectedType = type;
            _selectedStatus = status;
            _sortBy = sortBy;
            _orderBy = orderBy;
          });
          _fetchData(refresh: true);
        },
      ),
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildGridDelegate() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isDesktop = screenWidth >= 1024;

    // Responsive grid configuration
    final int crossAxisCount = isDesktop
        ? 5 // Desktop: 5 columns
        : isTablet
        ? 3 // Tablet: 3 columns
        : 2; // Mobile: 2 columns

    final double mainAxisSpacing = isDesktop
        ? 32 // Desktop: larger spacing
        : isTablet
        ? 28 // Tablet: medium spacing
        : 24; // Mobile: smaller spacing

    final double crossAxisSpacing = isDesktop
        ? 24 // Desktop: larger spacing
        : isTablet
        ? 20 // Tablet: medium spacing
        : 16; // Mobile: smaller spacing

    final double childAspectRatio = isDesktop
        ? 0.75 // Desktop: wider cards
        : isTablet
        ? 0.70 // Tablet: medium aspect ratio
        : 0.65; // Mobile: taller cards

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        onRefresh: () async {
          _fetchData(refresh: true);
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 500) {
              _fetchData();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor:
                    (isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight)
                        .withOpacity(0.8),
                surfaceTintColor: Colors.transparent,
                expandedHeight: 146,
                toolbarHeight: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DiscoverHeader(
                          isDark: isDark,
                          onSearch: _onSearch,
                          onShowQueue: _onShowQueue,
                          onSearchScrapSource: _onSearchScrapSource,
                          onFilter: _onFilter,
                          hasFilters:
                              _selectedGenres.isNotEmpty ||
                              _selectedType != null ||
                              _selectedStatus != null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No manga found')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                  sliver: SliverGrid(
                    gridDelegate: _buildGridDelegate(),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == _items.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final item = _items[index];

                      return DiscoverCard(
                        title: item.title,
                        type: item.type,
                        latestChapter: item.latestChapter,
                        views: formatViewCount(item.totalView),
                        genres: item.genres ?? [],
                        status: item.status,
                        rating: item.rating,
                        imageUrl: _apiService.getLocalImageUrl(
                          item.localImageUrl,
                          item.imageUrl,
                        ),
                        onTap: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          try {
                            final detailData = await _apiService.getMangaDetail(
                              item.id,
                            );
                            if (!mounted) return;
                            Navigator.pop(context); // Close loading dialog

                            final mangaDetail = MangaDetail.fromMap(detailData);

                            await Navigator.pushNamed(
                              context,
                              AppRoutes.detail,
                              arguments: mangaDetail,
                            );

                            if (mounted) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            }
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to load details: $e'),
                              ),
                            );
                          }
                        },
                      );
                    }, childCount: _items.length + (_isMoreLoading ? 1 : 0)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
