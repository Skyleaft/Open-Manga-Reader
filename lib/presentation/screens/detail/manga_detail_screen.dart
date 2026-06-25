import 'dart:ui';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/di/injection.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_manga.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/models/progression.dart';
import '../../../data/models/reader_content.dart';
import '../../../data/services/library_service.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/manga_detail_service.dart';
import '../../../data/services/progression_service.dart';
import '../../../routes/app_pages.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/discover_card.dart';
import '../../../core/config/app_config.dart';
import '../../../data/models/manga_summary.dart';

class MangaDetailScreen extends StatefulWidget {
  final MangaDetail manga;

  const MangaDetailScreen({super.key, required this.manga});

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen>
    with SingleTickerProviderStateMixin {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final ProgressionService _progressionService = getIt<ProgressionService>();
  final LibraryService _libraryService = getIt<LibraryService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();
  List<Chapter> _chapters = [];
  bool _isLoadingChapters = true;
  bool _isInLibrary = false;
  Future<List<MangaProgression>>? _progressionsFuture;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  late TabController _tabController;
  List<MangaSummary> _recommendations = [];
  bool _isLoadingRecommendations = false;
  bool _isAscending = false;

  MangaDetail get manga => widget.manga;

  @override
  void initState() {
    super.initState();
    _chapters = widget.manga.chapters;
    _progressionsFuture = _progressionService.getAllProgressions();
    _loadChapters();
    _checkIfInLibrary();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _recommendations.isEmpty) {
        _loadRecommendations();
      }
      if (mounted) setState(() {});
    });
    _sortChapters();
  }

  void _sortChapters() {
    _chapters.sort((a, b) {
      if (_isAscending) {
        return a.chapterNumber.compareTo(b.chapterNumber);
      } else {
        return b.chapterNumber.compareTo(a.chapterNumber);
      }
    });
  }

  void _toggleSort() {
    setState(() {
      _isAscending = !_isAscending;
      _sortChapters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProgressions() {
    if (mounted) {
      setState(() {
        _progressionsFuture = _progressionService.getAllProgressions();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoadingChapters = true);
    try {
      final chaptersData = await _apiService.getMangaChapters(manga.id);
      if (mounted) {
        final freshChapters = chaptersData
            .map((e) => Chapter.fromMap(e))
            .toList();
        setState(() {
          _chapters = freshChapters;
          _sortChapters();
          _isLoadingChapters = false;
        });
        // Persist refreshed data to local cache
        final freshDetail = MangaDetail(
          id: manga.id,
          malId: manga.malId,
          title: manga.title,
          author: manga.author,
          type: manga.type,
          genres: manga.genres,
          description: manga.description,
          imageUrl: manga.imageUrl,
          localImageUrl: manga.localImageUrl,
          rating: manga.rating,
          popularity: manga.popularity,
          members: manga.members,
          totalView: manga.totalView,
          status: manga.status,
          releaseDate: manga.releaseDate,
          createdAt: manga.createdAt,
          updatedAt: manga.updatedAt,
          url: manga.url,
          chapters: freshChapters,
        );
        await _detailService.saveDetail(freshDetail);
        _refreshProgressions();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChapters = false);
    }
  }

  Future<void> _loadChapters() async {
    // 1. Load from local cache first for instant offline display
    final cached = await _detailService.getDetail(manga.id);
    if (cached != null && cached.chapters.isNotEmpty && mounted) {
      setState(() {
        _chapters = cached.chapters;
        _sortChapters();
        _isLoadingChapters = false;
      });
    }

    // 2. Try to sync from API in the background
    try {
      final chaptersData = await _apiService.getMangaChapters(manga.id);
      if (mounted) {
        setState(() {
          _chapters = chaptersData.map((e) => Chapter.fromMap(e)).toList();
          _sortChapters();
          _isLoadingChapters = false;
        });
        // Update local cache with fresh chapter data
        final freshDetail = MangaDetail(
          id: manga.id,
          malId: manga.malId,
          title: manga.title,
          author: manga.author,
          type: manga.type,
          genres: manga.genres,
          description: manga.description,
          imageUrl: manga.imageUrl,
          localImageUrl: manga.localImageUrl,
          rating: manga.rating,
          popularity: manga.popularity,
          members: manga.members,
          totalView: manga.totalView,
          status: manga.status,
          releaseDate: manga.releaseDate,
          createdAt: manga.createdAt,
          updatedAt: manga.updatedAt,
          url: manga.url,
          chapters: _chapters,
        );
        await _detailService.saveDetail(freshDetail);
      }
    } catch (e) {
      if (mounted && _chapters.isEmpty) {
        setState(() {
          _isLoadingChapters = false;
        });
      }
    }
  }

  Future<void> _checkIfInLibrary() async {
    final isInLibrary = await _libraryService.isInLibrary(manga.id);
    if (mounted) {
      setState(() {
        _isInLibrary = isInLibrary;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    if (_isLoadingRecommendations) return;
    setState(() => _isLoadingRecommendations = true);
    try {
      final recommendations = await _apiService.getRecommendations(
        readingHistoryIds: [manga.id],
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  Future<void> _toggleLibrary(BuildContext context) async {
    try {
      if (_isInLibrary) {
        await _libraryService.removeFromLibrary(manga.id);
        AlertBanner.show(
          context,
          'Removed from library',
          type: AlertBannerType.success,
        );
      } else {
        final status = await _showStatusSelection(context);
        if (status == null) return; // User cancelled

        final libraryManga = LibraryManga.fromMangaDetail(
          manga.id,
          manga.title,
          manga.author,
          manga.displayImageUrl,
          manga.url,
          manga.type,
          status: status,
        );
        await _libraryService.addToLibrary(libraryManga);
        AlertBanner.show(
          context,
          'Added to library as $status',
          type: AlertBannerType.success,
        );
      }

      if (mounted) {
        setState(() {
          _isInLibrary = !_isInLibrary;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Error: ${e.toString()}',
          type: AlertBannerType.error,
        );
      }
    }
  }

  Future<String?> _showStatusSelection(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final statuses = [
          'Reading',
          'Completed',
          'OnHold',
          'Dropped',
          'PlanToRead',
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...statuses.map(
                (status) => ListTile(
                  title: Text(status),
                  onTap: () => Navigator.pop(context, status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Scrollable Content
          RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 400,
                  floating: false,
                  pinned: false,
                  snap: false,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _buildHeroSection(context),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16, top: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  actions: [
                    if (manga.url != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.public,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => launchUrlString(manga.url!),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(right: 16, top: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          final String shareUrl =
                              '${AppConfig.baseUrl}/manga/${manga.id}';
                          final String customSchemeUrl =
                              'skyleaft-manga://manga/${manga.id}';
                          final String shareText =
                              'Check out ${manga.title} on My Manga Reader!\n\n'
                              'Read it here: $shareUrl\n'
                              'Or open in app: $customSchemeUrl';

                          Share.share(
                            shareText,
                            subject: 'Share ${manga.title}',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainInfoSection(isDark),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 16),
                        // Divider before genre section
                        Container(
                          height: 1,
                          color: AppColors.primary.withOpacity(0.2),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        _buildGenreTags(),
                        const SizedBox(height: 24),
                        _buildSynopsis(),
                        const SizedBox(height: 24),
                        _buildActionButtons(context),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabHeaderDelegate(
                    backgroundColor: isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                    tabBar: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      tabs: const [
                        Tab(text: 'Chapters'),
                        Tab(text: 'Recommendations'),
                      ],
                    ),
                  ),
                ),
                if (_tabController.index == 0)
                  SliverToBoxAdapter(
                    child: Container(
                      color: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: _buildChapterListHeader(context),
                    ),
                  ),
                if (_tabController.index == 0)
                  _buildChapterListSliver(context, isDark)
                else
                  _buildRecommendationsSliver(context, isDark),
                SliverToBoxAdapter(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToReader(BuildContext context, Chapter chapter) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final pages = await _apiService.getChapterPages(
        manga.id,
        chapter.chapterNumber,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Get existing progression for this chapter
        final progression = await _progressionService.getProgression(manga.id);
        int startingPage = 1;

        if (progression != null &&
            progression.currentChapter == chapter.chapterNumber) {
          startingPage = progression.currentPage;
        }

        final content = ReaderContent(
          mangaId: manga.id,
          mangaTitle: manga.title,
          currentChapterNumber: chapter.chapterNumber,
          chapterId: chapter.id,
          allChapters: _chapters,
          chapterTitle: chapter.title,
          pageUrls: pages
              .map(
                (p) => _apiService.getLocalImageUrl(
                  p['localImageUrl'] as String?,
                  p['imageUrl'] as String?,
                ),
              )
              .toList(),
          currentPage: startingPage,
        );

        await Navigator.pushNamed(
          context,
          AppRoutes.reader,
          arguments: content,
        );
        _refreshProgressions();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        AlertBanner.show(
          context,
          'Failed to load chapter: $e',
          type: AlertBannerType.error,
        );
      }
    }
  }

  Widget _buildHeroSection(BuildContext context) {
    final imageUrl = _apiService.getLocalImageUrl(
      manga.localImageUrl,
      manga.imageUrl,
    );

    return Stack(
      children: [
        // Blurred background image
        imageUrl.isNotEmpty
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  height: 400,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    height: 400,
                    color: Colors.grey[800],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 400,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              )
            : Container(
                height: 400,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.white70,
                  ),
                ),
              ),

        // Centered manga cover thumbnail
        Center(
          child: Container(
            width: 230,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 32,
                          color: Colors.black54,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rating
        Column(
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.primary, size: 24),
                const SizedBox(width: 4),
                Text(
                  manga.rating?.toString() ?? '0.0',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            Text(
              '12.5k reviews',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Divider
        Container(
          height: 32,
          width: 1,
          color: AppColors.primary.withOpacity(0.2),
        ),
        const SizedBox(width: 24),
        // Chapters
        Column(
          children: [
            Text(
              _chapters.length.toString(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Chapters',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Divider
        Container(
          height: 32,
          width: 1,
          color: AppColors.primary.withOpacity(0.2),
        ),
        const SizedBox(width: 24),
        // Reads
        Column(
          children: [
            Text(
              formatViewCount(manga.totalView),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Reads',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainInfoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'TRENDING #1',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                manga.status?.toUpperCase() ?? 'ONGOING',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Title
        Text(
          manga.title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            shadows: [
              Shadow(
                color: isDark ? Colors.black87 : Colors.white70,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Author
        Text(
          'By ${manga.author}',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                color: isDark ? Colors.black87 : Colors.white70,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenreTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (manga.genres != null)
          ...manga.genres!.map(
            (genre) => _buildTag(
              genre,
              AppColors.primary.withOpacity(0.2),
              AppColors.primary,
            ),
          ),
        _buildTag(
          manga.status?.toUpperCase() ?? 'ONGOING',
          Colors.grey.withOpacity(0.2),
          Colors.grey,
        ),
        if (manga.releaseDate != null)
          _buildTag(
            'START: ${DateFormat('yyyy').format(manga.releaseDate!)}',
            Colors.blueAccent.withOpacity(0.2),
            Colors.blueAccent,
          ),
      ],
    );
  }

  Widget _buildTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSynopsis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Synopsis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          manga.description ?? 'No description available',
          style: const TextStyle(
            color: Colors.blueGrey,
            height: 1.6,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return FutureBuilder<List<MangaProgression>>(
      future: _progressionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildDefaultActionButtons(context);
        }

        final progressions = snapshot.data!;
        final currentProgression = progressions.firstWhereOrNull(
          (p) => p.mangaId == manga.id,
        );

        if (currentProgression != null) {
          return _buildResumeActionButtons(context, currentProgression);
        } else {
          return _buildDefaultActionButtons(context);
        }
      },
    );
  }

  Widget _buildDefaultActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: ElevatedButton.icon(
            onPressed: _isLoadingChapters
                ? null
                : () {
                    final availableChapters = _chapters
                        .where((c) => c.isChapterAvailable)
                        .toList();
                    if (availableChapters.isNotEmpty) {
                      // Assuming last is first chapter (earliest)
                      final firstAvailable = availableChapters.last;
                      _navigateToReader(context, firstAvailable);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoadingChapters
                  ? Colors.grey[700]
                  : _chapters.any((c) => c.isChapterAvailable)
                  ? AppColors.primary
                  : Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
              ),
            ),
            icon: const Icon(Icons.menu_book),
            label: const Text(
              'Read First Chapter',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56,
          width: 64,
          decoration: BoxDecoration(
            color: _isInLibrary ? AppColors.primary : Colors.grey[800],
            borderRadius: BorderRadius.circular(36),
          ),
          child: IconButton(
            icon: Icon(
              _isInLibrary ? Icons.library_add_check : Icons.library_add,
              color: Colors.white,
            ),
            onPressed: () => _toggleLibrary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeActionButtons(
    BuildContext context,
    MangaProgression progression,
  ) {
    // Find the exact chapter that matches the progression
    final exactChapter = _chapters.firstWhereOrNull(
      (c) =>
          c.isChapterAvailable && c.chapterNumber == progression.currentChapter,
    );

    // Find the next available chapter after the current progression
    final nextChapter = _chapters.firstWhereOrNull(
      (c) =>
          c.isChapterAvailable && c.chapterNumber > progression.currentChapter,
    );

    // Find the previous available chapter before the current progression
    final prevChapter = _chapters.lastWhereOrNull(
      (c) =>
          c.isChapterAvailable && c.chapterNumber < progression.currentChapter,
    );

    // Determine the actual target chapter and button text
    // Priority: 1) Exact match, 2) Next chapter, 3) Previous chapter, 4) First available
    final targetChapter =
        exactChapter ??
        nextChapter ??
        prevChapter ??
        _chapters.firstWhereOrNull((c) => c.isChapterAvailable);

    final buttonText = targetChapter != null
        ? 'Resume Chapter ${targetChapter.chapterNumber.toInt()}'
        : 'Resume Chapter ${progression.currentChapter.toInt()}';

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: ElevatedButton.icon(
            onPressed: () {
              if (targetChapter != null) {
                _navigateToReader(context, targetChapter);
              } else {
                // Fallback to first available chapter
                final availableChapters = _chapters
                    .where((c) => c.isChapterAvailable)
                    .toList();

                if (availableChapters.isNotEmpty) {
                  final firstAvailable = availableChapters.last;
                  _navigateToReader(context, firstAvailable);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 56,
          width: 64,
          decoration: BoxDecoration(
            color: _isInLibrary ? AppColors.primary : Colors.grey[800],
            borderRadius: BorderRadius.circular(36),
          ),
          child: IconButton(
            icon: Icon(
              _isInLibrary ? Icons.library_add_check : Icons.library_add,
              color: Colors.white,
            ),
            onPressed: () => _toggleLibrary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterListHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSearching) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate700.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chapter number...',
                  hintStyle: TextStyle(
                    color: (isDark ? Colors.white70 : Colors.black54)
                        .withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Chapters',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(
                Icons.search,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            IconButton(
              onPressed: () async {
                try {
                  AlertBanner.show(
                    context,
                    'Scraping chapters...',
                    type: AlertBannerType.info,
                  );
                  await _apiService.scrapChapterPagesNew(manga.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    AlertBanner.show(
                      context,
                      'Chapter scraping queued successfully!',
                      type: AlertBannerType.success,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AlertBanner.show(
                      context,
                      'Failed to scrap chapters: $e',
                      type: AlertBannerType.error,
                    );
                  }
                }
              },
              icon: const Icon(
                Icons.cloud_download_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            TextButton.icon(
              onPressed: _toggleSort,
              icon: Text(
                _isAscending ? 'Oldest' : 'Latest',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              label: AnimatedRotation(
                turns: _isAscending ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(
                  Icons.swap_vert,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChapterListSliver(BuildContext context, bool isDark) {
    final bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    if (_isLoadingChapters) {
      return SliverToBoxAdapter(
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.all(24.0),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final filteredChapters = _chapters.where((chapter) {
      if (_searchQuery.isEmpty) return true;
      final numStr = chapter.chapterNumber % 1 == 0
          ? chapter.chapterNumber.toInt().toString()
          : chapter.chapterNumber.toString();
      return numStr.contains(_searchQuery);
    }).toList();

    if (filteredChapters.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              _searchQuery.isEmpty
                  ? 'No chapters available'
                  : 'No chapters matching "$_searchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final chapter = filteredChapters[index];
        return Container(
          color: bgColor,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: _buildChapterItem(context, chapter, isDark),
        );
      }, childCount: filteredChapters.length),
    );
  }

  Widget _buildChapterItem(BuildContext context, Chapter chapter, bool isDark) {
    final bool isAvailable = chapter.isChapterAvailable;
    final Color chapterBgColor = isAvailable
        ? isDark
              ? AppColors.slate700.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1)
        : Colors.grey.shade600;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: isAvailable ? () => _navigateToReader(context, chapter) : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: chapterBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Chapter number circle/box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.slate700.withValues(alpha: 0.4)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        chapter.chapterNumber % 1 == 0
                            ? chapter.chapterNumber.toInt().toString()
                            : chapter.chapterNumber.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chapter info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Language Badge
                            if (chapter.language.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  chapter.language.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),

                            // Provider Badge
                            if (chapter.chapterProvider != null &&
                                chapter.chapterProvider!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (chapter.chapterProviderIcon !=
                                        null) ...[
                                      Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 4),
                                        child:
                                            chapter.chapterProviderIcon!
                                                .toLowerCase()
                                                .endsWith('.ico')
                                            ? Icon(
                                                Icons.link,
                                                size: 10,
                                                color: textColor.withValues(
                                                  alpha: 0.6,
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: chapter
                                                    .chapterProviderIcon!,
                                                width: 12,
                                                height: 12,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Icon(
                                                      Icons.link,
                                                      size: 10,
                                                      color: textColor
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                    ),
                                              ),
                                      ),
                                    ],
                                    Text(
                                      chapter.chapterProvider!,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // View Count
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: textColor.withValues(alpha: 0.5),
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  formatViewCount(chapter.totalView),
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Date row
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(chapter.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '·',
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo(chapter.date),
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: textColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right side: Status and arrow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCompletionBadge(chapter),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: textColor.withValues(alpha: 0.3),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progression bar
              _buildProgressionBar(chapter.chapterNumber),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompletionBadge(Chapter chapter) {
    return FutureBuilder<List<MangaProgression>>(
      future: _progressionsFuture,
      builder: (context, snapshot) {
        final double chapterNumber = chapter.chapterNumber;
        final bool isRead =
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.any((p) {
              if (p.mangaId != manga.id) return false;
              return p.chapterLogs.any(
                (log) => log.chapterNumber == chapterNumber && log.isCompleted,
              );
            });

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRead)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.4),
                      AppColors.primary.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'READ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProgressionBar(double chapterNumber) {
    return FutureBuilder<List<MangaProgression>>(
      future: _progressionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
            minHeight: 4,
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final progressions = snapshot.data!;
        final progression = progressions.firstWhereOrNull(
          (p) => p.mangaId == manga.id,
        );
        final log = progression?.chapterLogs.firstWhereOrNull(
          (l) => l.chapterNumber == chapterNumber,
        );

        if (log == null || log.isCompleted) {
          return const SizedBox.shrink();
        }

        final double progressPercentage = log.totalPages <= 0
            ? 0.0
            : (log.lastReadPage / log.totalPages).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress: ${(progressPercentage * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecommendationsSliver(BuildContext context, bool isDark) {
    final bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    if (_isLoadingRecommendations) {
      return SliverToBoxAdapter(
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.all(48.0),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: bgColor,
          padding: const EdgeInsets.all(48.0),
          child: const Center(
            child: Text(
              'No recommendations available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24.0),
      sliver: SliverGrid(
        gridDelegate: _buildRecommendationGridDelegate(),
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = _recommendations[index];
          return DiscoverCard(
            title: item.title,
            type: item.type,
            latestChapter: item.latestChapter,
            views: formatViewCount(item.totalView),
            genres: item.genres ?? [],
            status: item.status,
            rating: item.rating,
            localImageUrl: item.localImageUrl,
            imageUrl: item.imageUrl,
            onTap: () => _navigateToDetail(context, item),
          );
        }, childCount: _recommendations.length),
      ),
    );
  }

  SliverGridDelegateWithFixedCrossAxisCount _buildRecommendationGridDelegate() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isDesktop = screenWidth >= 1024;

    final int crossAxisCount = isDesktop
        ? 4
        : isTablet
        ? 3
        : 2;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 24,
      crossAxisSpacing: 16,
      childAspectRatio: 0.65,
    );
  }

  Future<void> _navigateToDetail(
    BuildContext context,
    MangaSummary item,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final detailData = await _apiService.getMangaDetail(item.id);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        final mangaDetail = MangaDetail.fromMap(detailData);
        Navigator.pushNamed(context, AppRoutes.detail, arguments: mangaDetail);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AlertBanner.show(
          context,
          'Failed to load details: $e',
          type: AlertBannerType.error,
        );
      }
    }
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) {
    return false;
  }
}
