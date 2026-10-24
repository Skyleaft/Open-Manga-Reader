import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/discover_card.dart';
import '../../../core/models/manga_summary.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../routes/app_pages.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../controllers/discover_controller.dart';
import 'widgets/discover_header.dart';
import 'widgets/discover_grid_skeleton.dart';
import 'widgets/scrap_queue_dialog.dart';
import 'widgets/filter_dialog.dart';

class DiscoverScreen extends StatefulWidget {
  final String? initialSearch;
  final String? sortBy;

  const DiscoverScreen({super.key, this.initialSearch, this.sortBy});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin {
  late final DiscoverController _controller;
  late final ScrollController _scrollController;
  final MangaApiService _apiService = getIt<MangaApiService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();

  bool _showScrollToTop = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverController(
      initialSearch: widget.initialSearch,
      initialSortBy: widget.sortBy,
    );
    _controller.addListener(_onControllerChanged);
    _scrollController = ScrollController()..addListener(_onScroll);
    _controller.fetchData(refresh: true);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updateParamsIfChanged(
      initialSearch: widget.initialSearch,
      sortBy: widget.sortBy,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show scroll to top button
    final show = _scrollController.hasClients && _scrollController.offset > 400;
    if (show != _showScrollToTop) {
      setState(() {
        _showScrollToTop = show;
      });
    }

    // Continuous Infinite Scroll: fetch next page when within 600px of bottom
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 600) {
      _controller.fetchData();
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
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
        initialFilter: _controller.filter,
        initialSort: _controller.sortOption,
        onApply: (newFilter, newSort) {
          _controller.applyFilterAndSort(newFilter, newSort);
        },
      ),
    );
  }

  Future<void> _navigateToDetail(MangaSummary item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final heroTag = 'manga-cover-discover-${item.id}';

    // Instant non-blocking transition: check cache first, otherwise construct initial MangaDetail
    // to allow smooth Hero animation without freezing the UI with a blocking modal dialog!
    final cached = await _detailService.getDetail(item.id);
    final targetDetail = cached ?? MangaDetail.fromMangaSummary(item);

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.detail,
      arguments: {
        'manga': targetDetail,
        'heroTag': heroTag,
      },
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildGridDelegate() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    final int crossAxisCount = isDesktop
        ? 5
        : isTablet
        ? 3
        : 2;

    final double mainAxisSpacing = isDesktop
        ? 32
        : isTablet
        ? 28
        : 24;

    final double crossAxisSpacing = isDesktop
        ? 24
        : isTablet
        ? 20
        : 16;

    final double childAspectRatio = isDesktop
        ? 0.75
        : isTablet
        ? 0.70
        : 0.65;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required Color color,
    required VoidCallback onDeleted,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        avatar: icon != null ? Icon(icon, size: 14, color: color) : null,
        selected: true,
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        onDeleted: onDeleted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildActiveFilterChips(bool isDark) {
    if (!_controller.hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];
    final filter = _controller.filter;

    // Included Genres
    for (final genre in filter.includedGenres) {
      chips.add(_buildFilterChip(
        label: genre,
        color: const Color(0xFF10B981),
        icon: Icons.check_circle_rounded,
        onDeleted: () => _controller.removeIncludedGenre(genre),
      ));
    }

    // Excluded Genres
    for (final genre in filter.excludedGenres) {
      chips.add(_buildFilterChip(
        label: 'NOT: $genre',
        color: const Color(0xFFEF4444),
        icon: Icons.cancel_rounded,
        onDeleted: () => _controller.removeExcludedGenre(genre),
      ));
    }

    // Types
    for (final type in filter.types) {
      chips.add(_buildFilterChip(
        label: 'Type: $type',
        color: Colors.blue,
        onDeleted: () => _controller.removeType(type),
      ));
    }

    // Statuses
    for (final status in filter.statuses) {
      chips.add(_buildFilterChip(
        label: 'Status: $status',
        color: Colors.teal,
        onDeleted: () => _controller.removeStatus(status),
      ));
    }

    // Author
    if (filter.author != null && filter.author!.isNotEmpty) {
      chips.add(_buildFilterChip(
        label: 'Author: ${filter.author}',
        color: Colors.purple,
        onDeleted: _controller.clearAuthor,
      ));
    }

    // Min Rating
    if (filter.minRating != null) {
      chips.add(_buildFilterChip(
        label: '⭐ ${filter.minRating!.toStringAsFixed(1)}+',
        color: Colors.amber.shade800,
        onDeleted: _controller.clearMinRating,
      ));
    }

    // Min Chapters
    if (filter.minChapters != null) {
      chips.add(_buildFilterChip(
        label: '${filter.minChapters}+ Chapters',
        color: Colors.orange.shade800,
        onDeleted: _controller.clearMinChapters,
      ));
    }

    // NSFW Content
    if (filter.nsfw != false) {
      chips.add(_buildFilterChip(
        label: filter.nsfw == true ? '18+ Only' : 'All Content (incl. 18+)',
        color: filter.nsfw == true ? Colors.red : Colors.orange,
        onDeleted: _controller.resetNsfw,
      ));
    }

    // Clear All Action
    chips.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: const Icon(Icons.clear_all_rounded, size: 16),
          label: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: _controller.clearAllFilters,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: chips,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No manga found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.hasActiveFilters
                  ? 'Try changing your search terms or filters.'
                  : 'No manga available at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (_controller.hasActiveFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _controller.clearAllFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reset Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            onRefresh: () async {
              await _controller.fetchData(refresh: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor:
                      (isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight)
                          .withValues(alpha: 0.8),
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
                            onSearch: _controller.onSearchChanged,
                            onShowQueue: _onShowQueue,
                            onSearchScrapSource: _onSearchScrapSource,
                            onFilter: _onFilter,
                            onAdvancedRecommendation: () =>
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.advancedRecommendation,
                                ),
                            hasFilters: _controller.hasActiveFilters,
                            isSemanticSearch: _controller.isSemanticSearch,
                            onSemanticSearchChanged: _controller.setSemanticSearch,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_controller.hasActiveFilters)
                  SliverToBoxAdapter(child: _buildActiveFilterChips(isDark)),
                if (_controller.isLoading)
                  const SliverToBoxAdapter(
                    child: DiscoverGridSkeleton(itemCount: 8),
                  )
                else if (_controller.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(isDark),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    sliver: SliverGrid(
                      gridDelegate: _buildGridDelegate(),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _controller.items[index];
                          return DiscoverCard(
                            title: item.title,
                            type: item.type,
                            latestChapter: item.latestChapter,
                            views: formatViewCount(item.totalView),
                            genres: item.genres ?? [],
                            status: item.status,
                            rating: item.rating,
                            heroTag: 'manga-cover-discover-${item.id}',
                            imageUrl: _apiService.getLocalImageUrl(
                              item.localImageUrl,
                              item.imageUrl,
                            ),
                            onTap: () => _navigateToDetail(item),
                          );
                        },
                        childCount: _controller.items.length,
                      ),
                    ),
                  ),
                  // Loading next page indicator cleanly centered outside grid cells
                  if (_controller.isMoreLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 90),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 90),
                    ),
                ],
              ],
            ),
          ),
          // Scroll To Top Floating Button
          Positioned(
            right: 20,
            bottom: 90,
            child: IgnorePointer(
              ignoring: !_showScrollToTop,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: _showScrollToTop ? Offset.zero : const Offset(0, 1),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _showScrollToTop ? 1.0 : 0.0,
                  curve: Curves.easeInOut,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _scrollToTop,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.92),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.4 : 0.12,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
