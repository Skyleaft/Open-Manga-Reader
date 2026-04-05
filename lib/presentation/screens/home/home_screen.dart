import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/manga_summary.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../core/di/injection.dart';
import '../../../routes/app_pages.dart';
import '../discover/discover_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function({String? sortBy, String? search})? onNavigateToDiscover;

  const HomeScreen({super.key, this.onNavigateToDiscover});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MangaApiService _apiService = getIt<MangaApiService>();

  List<MangaSummary> _trendingManga = [];
  List<MangaSummary> _latestUpdates = [];
  List<MangaSummary> _recommendedManga = [];
  List<MangaSummary> _topManga = [];

  bool _isLoadingTrending = true;
  bool _isLoadingLatest = true;
  bool _isLoadingRecommended = true;
  bool _isLoadingTop = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    _fetchTrending();
    _fetchLatest();
    _fetchTop().then((_) => _fetchRecommended());
  }

  Future<void> _fetchTrending() async {
    try {
      final response = await _apiService.getPagedManga(
        sortBy: 'totalView',
        orderBy: 'desc',
        pageSize: 10,
      );
      if (mounted) {
        setState(() {
          _trendingManga = response.items;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTrending = false);
      }
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
      if (mounted) {
        setState(() => _isLoadingLatest = false);
      }
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
      if (mounted) {
        setState(() => _isLoadingRecommended = false);
      }
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
      if (mounted) {
        setState(() => _isLoadingTop = false);
      }
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
      Navigator.pop(context); // Close loading dialog

      final mangaDetail = MangaDetail.fromMap(detailData);

      Navigator.pushNamed(context, AppRoutes.detail, arguments: mangaDetail);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _fetchData,
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
                  _buildTrendingManga(context),
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
            onTap: () {
              // Navigation to profile or library can be here
            },
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

  Widget _buildTrendingManga(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trending Manga',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: _isLoadingTrending
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _trendingManga.length,
                  itemBuilder: (context, index) {
                    final manga = _trendingManga[index];
                    return _buildTrendingItem(
                      context,
                      manga,
                      'Hot #${index + 1}',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem(
    BuildContext context,
    MangaSummary manga,
    String tag,
  ) {
    final String imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return GestureDetector(
      onTap: () => _navigateToDetail(manga.id),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${manga.type} • Ch. ${manga.latestChapter?.number ?? 0}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

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
