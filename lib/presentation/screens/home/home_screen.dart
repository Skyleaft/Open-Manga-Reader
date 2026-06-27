import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../data/models/manga_summary.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/models/progression.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/manga_detail_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/di/injection.dart';
import '../../../routes/app_pages.dart';
import '../discover/discover_screen.dart';

// ---------------------------------------------------------------------------
// Genre tab definition
// ---------------------------------------------------------------------------
class _TrendingTab {
  final String label;
  final String? genre; // null = "All"
  final Color color;
  final IconData icon;

  const _TrendingTab({
    required this.label,
    this.genre,
    required this.color,
    required this.icon,
  });
}

const List<_TrendingTab> _kTrendingTabs = [
  _TrendingTab(
    label: 'All',
    genre: null,
    color: Color(0xFF3498DB),
    icon: Icons.local_fire_department_rounded,
  ),
  _TrendingTab(
    label: 'Action',
    genre: 'Action',
    color: Color(0xFFE74C3C),
    icon: Icons.flash_on_rounded,
  ),
  _TrendingTab(
    label: 'Romance',
    genre: 'Romance',
    color: Color(0xFFE91E8C),
    icon: Icons.favorite_rounded,
  ),
  _TrendingTab(
    label: 'Fantasy',
    genre: 'Fantasy',
    color: Color(0xFF9B59B6),
    icon: Icons.auto_awesome_rounded,
  ),
  _TrendingTab(
    label: 'Comedy',
    genre: 'Comedy',
    color: Color(0xFFF39C12),
    icon: Icons.sentiment_very_satisfied_rounded,
  ),
  _TrendingTab(
    label: 'Ecchi',
    genre: 'Ecchi',
    color: Color(0xFFFF5722),
    icon: Icons.whatshot_rounded,
  ),
  _TrendingTab(
    label: 'Slice of Life',
    genre: 'Slice of Life',
    color: Color(0xFF27AE60),
    icon: Icons.spa_rounded,
  ),
];

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final Function({String? sortBy, String? search})? onNavigateToDiscover;

  const HomeScreen({super.key, this.onNavigateToDiscover});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final ProgressionService _progressionService = getIt<ProgressionService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();

  // Trending tab controller & per-tab cache
  late TabController _trendingTabController;
  final Map<int, List<MangaSummary>> _trendingByTab = {};
  final Map<int, bool> _trendingLoadingByTab = {};

  List<MangaSummary> _latestUpdates = [];
  List<MangaSummary> _recommendedManga = [];
  List<MangaSummary> _topManga = [];

  // History
  List<MangaProgression> _recentProgressions = [];
  Map<String, MangaDetail> _historyDetailsMap = {};
  bool _isLoadingHistory = true;

  bool _isLoadingLatest = true;
  bool _isLoadingRecommended = true;
  bool _isLoadingTop = true;

  @override
  void initState() {
    super.initState();
    _trendingTabController = TabController(
      length: _kTrendingTabs.length,
      vsync: this,
    );
    _trendingTabController.addListener(_onTrendingTabChanged);
    _fetchData();
  }

  @override
  void dispose() {
    _trendingTabController.removeListener(_onTrendingTabChanged);
    _trendingTabController.dispose();
    super.dispose();
  }

  void _onTrendingTabChanged() {
    final idx = _trendingTabController.index;
    if (!_trendingTabController.indexIsChanging) return;
    if (!_trendingByTab.containsKey(idx)) {
      _fetchTrendingForTab(idx);
    }
  }

  Future<void> _fetchData() async {
    _fetchHistory();
    _fetchTrendingForTab(0); // load "All" tab eagerly
    _fetchLatest();
    _fetchTop().then((_) => _fetchRecommended());
  }

  Future<void> _fetchTrendingForTab(int tabIdx) async {
    if (_trendingLoadingByTab[tabIdx] == true) return;
    if (mounted) setState(() => _trendingLoadingByTab[tabIdx] = true);
    try {
      final tab = _kTrendingTabs[tabIdx];
      final response = await _apiService.getTrending(
        genres: tab.genre != null ? [tab.genre!] : null,
        pageSize: 10,
      );
      if (mounted) {
        setState(() {
          _trendingByTab[tabIdx] = response.items;
          _trendingLoadingByTab[tabIdx] = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _trendingLoadingByTab[tabIdx] = false);
    }
  }

  Future<void> _fetchHistory() async {
    if (mounted) setState(() => _isLoadingHistory = true);
    try {
      final progressions = await _progressionService.getAllProgressions();
      progressions.sort((a, b) => b.lastRead.compareTo(a.lastRead));
      final recent = progressions.take(10).toList();

      final detailsMap = <String, MangaDetail>{};
      for (final p in recent) {
        try {
          final cached = await _detailService.getDetail(p.mangaId);
          if (cached != null) {
            detailsMap[p.mangaId] = cached;
          } else {
            final data = await _apiService.getMangaDetail(p.mangaId);
            final detail = MangaDetail.fromMap(data);
            await _detailService.saveDetail(detail);
            detailsMap[p.mangaId] = detail;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _recentProgressions = recent;
          _historyDetailsMap = detailsMap;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _fetchLatest() async {
    try {
      final response = await _apiService.getPagedManga(
        sortBy: 'updatedAt',
        orderBy: 'desc',
        pageSize: 5,
      );
      if (mounted) {
        setState(() {
          _latestUpdates = response.items;
          _isLoadingLatest = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLatest = false);
    }
  }

  Future<void> _fetchRecommended() async {
    try {
      final history = await getIt<ProgressionService>().getAllProgressions();
      List<String> ids = history.map((e) => e.mangaId).toList();

      if (ids.isEmpty && _topManga.isNotEmpty) {
        ids = [_topManga.first.id];
      }

      final items = await _apiService.getRecommendations(
        readingHistoryIds: ids,
        limit: 6,
      );
      if (mounted) {
        setState(() {
          _recommendedManga = items;
          _isLoadingRecommended = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecommended = false);
    }
  }

  Future<void> _fetchTop() async {
    try {
      final response = await _apiService.getPagedManga(
        sortBy: 'rating',
        orderBy: 'desc',
        pageSize: 6,
      );
      if (mounted) {
        setState(() {
          _topManga = response.items;
          _isLoadingTop = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTop = false);
    }
  }

  Future<void> _navigateToDetail(String mangaId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final detailData = await _apiService.getMangaDetail(mangaId);
      if (!mounted) return;
      Navigator.pop(context);

      final mangaDetail = MangaDetail.fromMap(detailData);
      Navigator.pushNamed(context, AppRoutes.detail, arguments: mangaDetail);
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

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        _trendingByTab.clear();
        _trendingLoadingByTab.clear();
        _fetchData();
      },
      color: AppColors.primary,
      child: SafeArea(
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
              expandedHeight: 100,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: _buildHeader(context, isDark),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 150),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  _buildContinueReading(context, isDark),
                  const SizedBox(height: 32),
                  _buildTrendingSection(context, isDark),
                  const SizedBox(height: 32),
                  _buildLatestUpdates(context, isDark),
                  const SizedBox(height: 32),
                  _buildTopManga(context),
                  const SizedBox(height: 32),
                  _buildRecommendedGrid(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, bool isDark) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Open Manga Reader',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 2,
                ),
                image: DecorationImage(
                  image: NetworkImage(
                    authService.currentUser?.photoURL ??
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuAOmebCcL-tBf75LvGc6ipwfwsOuoOk0JHFI9_-bxtFtzxg-Gvn9k6VI8MliWvYzLg-xAeQ0SagmyxKKE1Z_36s2wkff5JPgMEk5XhogzNBDh-vl1XFdn6pGT9Spt-6zIdcPzfQewpZYs-2jpZ_47qkNM163fNM3IqQYOQzFQcEA10umHVOHOxSCj7ZoHIeGZ-VAH5EcWQiV9sXiomk3tZR36v18pacx1xwmqmWlEo7MrOgSh2JYUQwJxqkICkhRDy2n0dALOilShrw',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Continue Reading
  // -------------------------------------------------------------------------
  Widget _buildContinueReading(BuildContext context, bool isDark) {
    if (!_isLoadingHistory && _recentProgressions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Continue Reading',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.history),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: _isLoadingHistory
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recentProgressions.length,
                  itemBuilder: (context, index) {
                    final progression = _recentProgressions[index];
                    final detail = _historyDetailsMap[progression.mangaId];
                    return _buildHistoryCard(
                      context,
                      progression,
                      detail,
                      isDark,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    MangaProgression progression,
    MangaDetail? detail,
    bool isDark,
  ) {
    final imageUrl = detail != null
        ? _apiService.getLocalImageUrl(detail.localImageUrl, detail.imageUrl)
        : '';
    final title = detail?.title ?? 'Unknown Manga';
    final progress = progression.progressPercentage;
    final now = DateTime.now();
    final diff = now.difference(progression.lastRead.toLocal());
    String timeAgo;
    if (diff.inDays >= 1) {
      timeAgo = '${diff.inDays}d ago';
    } else if (diff.inHours >= 1) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inMinutes >= 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else {
      timeAgo = 'Just now';
    }

    return GestureDetector(
      onTap: () async {
        if (detail != null) {
          Navigator.pushNamed(context, AppRoutes.detail, arguments: detail);
        }
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? AppColors.slate800.withOpacity(0.9) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                      ),
                      errorBuilder: (_, _, _) => Container(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.3, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.88),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeAgo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ch. ${progression.currentChapter.toInt()}  •  Pg. ${progression.currentPage}/${progression.totalPages}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Trending Section — modern tabbed card view
  // -------------------------------------------------------------------------
  Widget _buildTrendingSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF6B35), Color(0xFFE74C3C)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Trending',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFE74C3C)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🔥 HOT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateToDiscover != null) {
                    widget.onNavigateToDiscover!(sortBy: 'totalView');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DiscoverScreen(sortBy: 'totalView'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Genre tabs
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kTrendingTabs.length,
            itemBuilder: (context, index) {
              return _buildGenreTab(context, index, isDark);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Cards — fixed height TabBarView equivalent using AnimatedSwitcher
        SizedBox(
          height: 260,
          child: TabBarView(
            controller: _trendingTabController,
            children: List.generate(_kTrendingTabs.length, (tabIdx) {
              return _buildTrendingTabContent(context, tabIdx, isDark);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildGenreTab(BuildContext context, int index, bool isDark) {
    final tab = _kTrendingTabs[index];
    return AnimatedBuilder(
      animation: _trendingTabController,
      builder: (context, _) {
        final isSelected = _trendingTabController.index == index;
        return GestureDetector(
          onTap: () {
            _trendingTabController.animateTo(index);
            if (!_trendingByTab.containsKey(index)) {
              _fetchTrendingForTab(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [tab.color, tab.color.withOpacity(0.75)],
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.06)),
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white12
                          : Colors.black.withOpacity(0.08),
                    ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  size: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 5),
                Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingTabContent(
    BuildContext context,
    int tabIdx,
    bool isDark,
  ) {
    final isLoading = _trendingLoadingByTab[tabIdx] ?? true;
    final items = _trendingByTab[tabIdx] ?? [];
    final tabColor = _kTrendingTabs[tabIdx].color;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: tabColor, strokeWidth: 2.5),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 8),
            Text(
              'No trending manga found',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildTrendingCard(
          context,
          items[index],
          index,
          tabColor,
          isDark,
        );
      },
    );
  }

  Widget _buildTrendingCard(
    BuildContext context,
    MangaSummary manga,
    int rank,
    Color tabColor,
    bool isDark,
  ) {
    final String imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return GestureDetector(
      onTap: () => _navigateToDetail(manga.id),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card body
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: tabColor.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image
                    imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => Container(
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[200],
                            ),
                            errorBuilder: (_, _, _) => Container(
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: isDark ? Colors.grey[850] : Colors.grey[200],
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            ),
                          ),

                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.35, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.85),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom info
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Genre chip
                            if (manga.genres != null &&
                                manga.genres!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tabColor.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  manga.genres!.first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            Text(
                              manga.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.remove_red_eye_outlined,
                                  size: 10,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatViews(manga.totalView),
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 10,
                                  color: Colors.white54,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Ch.${manga.latestChapter?.number.toInt() ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Rank badge — glassmorphism pill
            Positioned(
              top: 10,
              left: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: rank < 3
                          ? tabColor.withOpacity(0.82)
                          : Colors.black.withOpacity(0.50),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (rank == 0)
                          const Text('🥇', style: TextStyle(fontSize: 10))
                        else if (rank == 1)
                          const Text('🥈', style: TextStyle(fontSize: 10))
                        else if (rank == 2)
                          const Text('🥉', style: TextStyle(fontSize: 10))
                        else ...[
                          Text(
                            '#${rank + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Rating badge top-right
            if (manga.rating != null)
              Positioned(
                top: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFC107),
                            size: 11,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            manga.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  // -------------------------------------------------------------------------
  // Latest Updates
  // -------------------------------------------------------------------------
  Widget _buildLatestUpdates(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Latest Update',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateToDiscover != null) {
                    widget.onNavigateToDiscover!(sortBy: 'updatedAt');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DiscoverScreen(sortBy: 'updatedAt'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'View More',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingLatest)
            const Center(child: CircularProgressIndicator())
          else if (_latestUpdates.isEmpty)
            const Text('No updates found')
          else
            ..._latestUpdates.map(
              (manga) => Column(
                children: [
                  _buildUpdateItem(context, manga, isDark),
                  const SizedBox(height: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpdateItem(
    BuildContext context,
    MangaSummary manga,
    bool isDark,
  ) {
    final String imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return GestureDetector(
      onTap: () => _navigateToDetail(manga.id),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 60,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          manga.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chapter ${manga.latestChapter?.number ?? 0}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatUploadDate(manga.latestChapter?.uploadDate),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.bookmark_add_outlined, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatUploadDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  // -------------------------------------------------------------------------
  // Top Manga
  // -------------------------------------------------------------------------
  Widget _buildTopManga(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Manga',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateToDiscover != null) {
                    widget.onNavigateToDiscover!(sortBy: 'rating');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DiscoverScreen(sortBy: 'rating'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingTop)
            const Center(child: CircularProgressIndicator())
          else if (_topManga.isEmpty)
            const Text('No top manga found')
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _topManga.length,
                itemBuilder: (context, index) {
                  final manga = _topManga[index];
                  return _buildSmallCard(context, manga);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmallCard(BuildContext context, MangaSummary manga) {
    final String imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return GestureDetector(
      onTap: () => _navigateToDetail(manga.id),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.yellow,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            manga.rating?.toStringAsFixed(1) ?? '0.0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              manga.title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Recommended Grid
  // -------------------------------------------------------------------------
  Widget _buildRecommendedGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended for You',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_isLoadingRecommended)
            const Center(child: CircularProgressIndicator())
          else if (_recommendedManga.isEmpty)
            const Text('No recommendations found')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recommendedManga.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemBuilder: (context, index) {
                final manga = _recommendedManga[index];
                return _buildRecommendedItem(context, manga);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendedItem(BuildContext context, MangaSummary manga) {
    final String imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return GestureDetector(
      onTap: () => _navigateToDetail(manga.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.yellow, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          manga.rating?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            manga.title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
