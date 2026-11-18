import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../../routes/app_pages.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../controllers/history_controller.dart';
import '../models/progression.dart';
import 'widgets/history_header.dart';
import 'widgets/history_item_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with RouteAware {
  late final HistoryController _controller;
  final MangaApiService _apiService = getIt<MangaApiService>();
  final TextEditingController _searchController = TextEditingController();
  bool _isRouteSubscribed = false;

  @override
  void initState() {
    super.initState();
    _controller = HistoryController();
    _controller.loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteSubscribed) {
      final modalRoute = ModalRoute.of(context);
      if (modalRoute is PageRoute) {
        AppRoutes.routeObserver.subscribe(this, modalRoute);
        _isRouteSubscribed = true;
      }
    }
  }

  @override
  void dispose() {
    if (_isRouteSubscribed) {
      AppRoutes.routeObserver.unsubscribe(this);
    }
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _controller.loadHistory();
  }

  Future<void> _navigateToDetail(MangaProgression progression) async {
    MangaDetail? detail = _controller.mangaDetailsMap[progression.mangaId];

    if (detail == null && progression.manga != null) {
      detail = MangaDetail.fromMangaSummary(progression.manga!);
    }

    if (detail != null) {
      await Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: detail,
      );
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _controller.loadHistory();
        });
      }
      return;
    }

    try {
      final detailData = await _apiService.getMangaDetail(progression.mangaId);
      if (!mounted) return;
      final fetched = MangaDetail.fromMap(detailData);
      await Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: fetched,
      );
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _controller.loadHistory();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _controller.refresh,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: (isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight)
                        .withValues(alpha: 0.8),
                    surfaceTintColor: Colors.transparent,
                    expandedHeight: 180,
                    toolbarHeight: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: HistoryHeader(
                            isDark: isDark,
                            selectedFilter: _controller.selectedFilter,
                            searchController: _searchController,
                            onSearchChanged: _controller.setSearchQuery,
                            onFilterChanged: _controller.setSelectedFilter,
                            onRefresh: _controller.refresh,
                            onClearAll: _controller.clearAllHistory,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    sliver: _buildContent(context, isDark),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_controller.isLoading && _controller.progressions.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildSkeletonItem(),
          childCount: 4,
        ),
      );
    }

    final filtered = _controller.filteredProgressions;
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _controller.searchQuery.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.auto_stories_outlined,
                size: 56,
                color: isDark ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 16),
              Text(
                _controller.searchQuery.isNotEmpty ||
                        _controller.selectedFilter != 'All'
                    ? 'No matching reading history found'
                    : 'No reading history yet\nStart reading manga to see your progress here!',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final progression = filtered[index];
        final mangaDetail = _controller.mangaDetailsMap[progression.mangaId];

        return HistoryItemCard(
          progression: progression,
          mangaDetail: mangaDetail,
          isDark: isDark,
          apiService: _apiService,
          onTap: () => _navigateToDetail(progression),
          onDelete: () => _controller.deleteProgression(progression.mangaId),
        );
      }, childCount: filtered.length),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const ShimmerBox(width: 76, height: 106, borderRadius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: double.infinity, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 140, height: 12, borderRadius: 4),
                SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 6, borderRadius: 3),
                SizedBox(height: 8),
                ShimmerBox(width: 80, height: 10, borderRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

