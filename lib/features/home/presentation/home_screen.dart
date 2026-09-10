import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/models/manga_summary.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../routes/app_pages.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../controllers/home_controller.dart';
import '../models/trending_tab.dart';
import 'widgets/home_header.dart';
import 'widgets/home_hero_carousel.dart';
import 'widgets/home_continue_reading_section.dart';
import 'widgets/home_trending_section.dart';
import 'widgets/home_latest_updates_section.dart';
import 'widgets/home_top_manga_section.dart';
import 'widgets/home_recommended_section.dart';

class HomeScreen extends StatefulWidget {
  final Function({String? sortBy, String? search})? onNavigateToDiscover;

  const HomeScreen({super.key, this.onNavigateToDiscover});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        SingleTickerProviderStateMixin,
        RouteAware,
        AutomaticKeepAliveClientMixin {
  late final HomeController _controller;
  late final TabController _trendingTabController;
  final MangaApiService _apiService = getIt<MangaApiService>();
  bool _isRouteSubscribed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _trendingTabController = TabController(
      length: kTrendingTabs.length,
      vsync: this,
    );
    _trendingTabController.addListener(_onTrendingTabChanged);
    _controller.fetchAllData();
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
    _trendingTabController.removeListener(_onTrendingTabChanged);
    _trendingTabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Automatically re-fetch reading progression when navigating back to HomeScreen
    _controller.fetchHistory();
  }

  void _onTrendingTabChanged() {
    final idx = _trendingTabController.index;
    if (!_controller.trendingByTab.containsKey(idx)) {
      _controller.fetchTrendingForTab(idx);
    }
  }

  Future<void> _navigateToDetail(
    String mangaId, {
    MangaDetail? detail,
    MangaSummary? summary,
    String? heroTag,
  }) async {
    MangaDetail? targetDetail = detail;

    // If detail is passed directly, use it
    if (targetDetail == null && summary != null) {
      targetDetail = MangaDetail.fromMangaSummary(summary);
    } else if (targetDetail == null &&
        _controller.historyDetailsMap.containsKey(mangaId)) {
      targetDetail = _controller.historyDetailsMap[mangaId];
    }

    if (targetDetail != null) {
      await Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: {
          'manga': targetDetail,
          'heroTag': heroTag,
        },
      );
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _controller.fetchHistory();
        });
      }
      return;
    }

    // Fallback: fetch detail before navigating
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final detailData = await _apiService.getMangaDetail(mangaId);
      if (!mounted) return;
      Navigator.pop(context);

      final mangaDetail = MangaDetail.fromMap(detailData);
      await Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: {
          'manga': mangaDetail,
          'heroTag': heroTag,
        },
      );
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _controller.fetchHistory();
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      AlertBanner.show(
        context,
        'Failed to load details: $e',
        type: AlertBannerType.error,
      );
    }
  }

  void _navigateToDiscover({String? sortBy, String? search}) {
    if (widget.onNavigateToDiscover != null) {
      widget.onNavigateToDiscover!(sortBy: sortBy, search: search);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DiscoverScreen(sortBy: sortBy, initialSearch: search),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      color: AppColors.primary,
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: (isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight)
                  .withValues(alpha: 0.8),
              surfaceTintColor: Colors.transparent,
              expandedHeight: 80,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: RepaintBoundary(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: HomeHeader(
                        isDark: isDark,
                        onSearchTap: () => _navigateToDiscover(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: SliverList.list(
                children: [
                  const SizedBox(height: 12),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeHeroCarousel(
                        mangaList: _controller.heroManga,
                        isLoading: _controller.isLoadingHero,
                        apiService: _apiService,
                        onSelectManga: (id, {summary, heroTag}) =>
                            _navigateToDetail(
                              id,
                              summary: summary,
                              heroTag: heroTag ?? 'manga-cover-hero-$id',
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeContinueReadingSection(
                        recentProgressions: _controller.recentProgressions,
                        historyDetailsMap: _controller.historyDetailsMap,
                        isLoading: _controller.isLoadingHistory,
                        isDark: isDark,
                        apiService: _apiService,
                        onSelectManga: (id, {detail}) =>
                            _navigateToDetail(
                              id,
                              detail: detail,
                              heroTag: 'manga-cover-continue-$id',
                            ),
                        onNavigateToHistory: () async {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.history,
                          );
                          if (mounted) {
                            _controller.fetchHistory();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeTrendingSection(
                        tabController: _trendingTabController,
                        trendingByTab: _controller.trendingByTab,
                        trendingLoadingByTab: _controller.trendingLoadingByTab,
                        isDark: isDark,
                        apiService: _apiService,
                        onSelectManga: (id, {summary, heroTag}) =>
                            _navigateToDetail(
                              id,
                              summary: summary,
                              heroTag: heroTag ?? 'manga-cover-trending-$id',
                            ),
                        onNavigateToDiscover: () =>
                            _navigateToDiscover(sortBy: 'totalView'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeLatestUpdatesSection(
                        latestUpdates: _controller.latestUpdates,
                        isLoading: _controller.isLoadingLatest,
                        isDark: isDark,
                        apiService: _apiService,
                        onSelectManga: (id, {summary}) =>
                            _navigateToDetail(
                              id,
                              summary: summary,
                              heroTag: 'manga-cover-latest-$id',
                            ),
                        onNavigateToDiscover: () =>
                            _navigateToDiscover(sortBy: 'updatedAt'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeTopMangaSection(
                        topManga: _controller.topManga,
                        isLoading: _controller.isLoadingTop,
                        isDark: isDark,
                        apiService: _apiService,
                        onSelectManga: (id, {summary}) =>
                            _navigateToDetail(
                              id,
                              summary: summary,
                              heroTag: 'manga-cover-top-$id',
                            ),
                        onNavigateToDiscover: () =>
                            _navigateToDiscover(sortBy: 'rating'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => HomeRecommendedSection(
                        recommendedManga: _controller.recommendedManga,
                        isLoading: _controller.isLoadingRecommended,
                        isDark: isDark,
                        apiService: _apiService,
                        onSelectManga: (id, {summary}) =>
                            _navigateToDetail(
                              id,
                              summary: summary,
                              heroTag: 'manga-cover-recommended-$id',
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

