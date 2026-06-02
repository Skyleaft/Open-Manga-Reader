import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/manga_card.dart';
import '../../../data/models/library_manga.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/services/library_service.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/manga_detail_service.dart';
import '../../../routes/app_pages.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final LibraryService _libraryService = getIt<LibraryService>();
  final MangaApiService _apiService = getIt<MangaApiService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();
  List<LibraryManga> _libraryMangas = [];
  Map<String, MangaDetail> _cachedDetails = {};
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final libraryMangas = await _libraryService.getAllLibraryMangas();
      final Map<String, MangaDetail> details = {};
      for (final manga in libraryMangas) {
        final detail = await _detailService.getDetail(manga.id);
        if (detail != null) {
          details[manga.id] = detail;
        }
      }
      if (mounted) {
        setState(() {
          _libraryMangas = libraryMangas;
          _cachedDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    // Force a fresh API fetch then reload from the updated local cache
    final apiService = getIt<MangaApiService>();
    try {
      await apiService.getUserLibrary();
      await apiService.getUserProgression();
    } catch (_) {}
    await _loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
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
              expandedHeight: 220,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              sliver: _buildContent(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.history);
                },
                icon: const Icon(Icons.history_outlined),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search in library',
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Reading'),
                _buildFilterChip('Completed'),
                _buildFilterChip('OnHold'),
                _buildFilterChip('Dropped'),
                _buildFilterChip('PlanToRead'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isActive = _selectedStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : Colors.grey[200]!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final filteredMangas = _libraryMangas.where((m) {
      final matchesStatus =
          _selectedStatus == 'All' ||
          m.status.toLowerCase() == _selectedStatus.toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredMangas.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              _selectedStatus == 'All'
                  ? 'Your library is empty\nAdd some manga to get started!'
                  : 'No manga with status $_selectedStatus',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final manga = filteredMangas[index];
        final detail = _cachedDetails[manga.id];
        return _buildMangaListItem(context, manga, detail, isDark);
      }, childCount: filteredMangas.length),
    );
  }

  Widget _buildMangaListItem(
    BuildContext context,
    LibraryManga manga,
    MangaDetail? detail,
    bool isDark,
  ) {
    final String displayUrl = getIt<MangaApiService>().getLocalImageUrl(
      detail?.localImageUrl ?? manga.imageUrl,
      manga.imageUrl,
    );

    // Excerpt of the description
    String excerpt = '';
    if (detail?.description != null && detail!.description!.isNotEmpty) {
      excerpt = detail.description!;
    } else {
      excerpt = 'No description available';
    }

    final int totalChapters = detail?.chapters.length ?? 0;
    final String displayAuthor =
        (detail != null &&
            detail.author.isNotEmpty &&
            detail.author != 'Unknown Author')
        ? detail.author
        : manga.author;

    return GestureDetector(
      onTap: () async {
        final mangaId = manga.id;
        final cached = await _detailService.getDetail(mangaId);

        if (!context.mounted) return;

        if (cached != null) {
          await Navigator.pushNamed(
            context,
            AppRoutes.detail,
            arguments: cached,
          );
          if (context.mounted) {
            _loadLibrary();
          }
          _apiService
              .getMangaDetail(mangaId)
              .then((data) {
                final fresh = MangaDetail.fromMap(data);
                _detailService.saveDetail(fresh);
              })
              .catchError((_) {});
          return;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        try {
          final detailData = await _apiService.getMangaDetail(mangaId);
          if (!context.mounted) return;
          Navigator.pop(context);

          final mangaDetail = MangaDetail.fromMap(detailData);
          await _detailService.saveDetail(mangaDetail);

          if (!context.mounted) return;
          await Navigator.pushNamed(
            context,
            AppRoutes.detail,
            arguments: mangaDetail,
          );
          if (context.mounted) {
            _loadLibrary();
          }
        } catch (e) {
          if (!context.mounted) return;
          Navigator.pop(context);
          AlertBanner.show(
            context,
            'Failed to load details: $e',
            type: AlertBannerType.error,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image Left
                Stack(
                  children: [
                    Container(
                      width: 105,
                      height: 145,
                      color: AppColors.primary.withOpacity(0.05),
                      child: displayUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: displayUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  _buildImagePlaceholder(),
                              placeholder: (context, url) =>
                                  _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
                    ),
                    // Progress Bar overlay at bottom of image
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 4,
                        color: Colors.black.withOpacity(0.2),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: manga.progressPercentage.clamp(0.0, 1.0),
                          child: Container(color: AppColors.primary),
                        ),
                      ),
                    ),
                    if (manga.isCompleted)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DONE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Information details Right
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    manga.title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusBadge(manga.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By $displayAuthor • ${manga.type}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Description Excerpt
                        Expanded(
                          child: Text(
                            excerpt,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Genres Row & Progress Text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child:
                                  detail?.genres != null &&
                                      detail!.genres!.isNotEmpty
                                  ? Text(
                                      detail.genres!.join(', '),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      'No genres loaded',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey[500],
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Ch. ${manga.currentChapter.toInt()}${totalChapters > 0 ? '/$totalChapters' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.menu_book,
        color: AppColors.primary.withOpacity(0.4),
        size: 28,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status.toLowerCase()) {
      'reading' => Colors.green,
      'completed' => Colors.blue,
      'onhold' => Colors.orange,
      'dropped' => Colors.red,
      'plantoread' => Colors.purple,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
