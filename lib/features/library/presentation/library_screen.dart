import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/models/chapter_page.dart';
import '../../../routes/app_pages.dart';
import '../../download/services/download_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../../manga_detail/presentation/widgets/status_selection_sheet.dart';
import '../../reader/models/reader_content.dart';
import '../controllers/library_controller.dart';
import '../models/library_manga.dart';
import 'widgets/library_header.dart';
import 'widgets/library_manga_card.dart';
import 'widgets/library_manga_grid_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with RouteAware, AutomaticKeepAliveClientMixin {
  late final LibraryController _controller;
  final MangaApiService _apiService = getIt<MangaApiService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();

  bool get _isOffline =>
      getIt.isRegistered<NetworkStatusService>() &&
      !getIt<NetworkStatusService>().isOnline;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = LibraryController();
    _controller.loadLibrary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      AppRoutes.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppRoutes.routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when navigating back, reload from local cache without triggering network calls
    _controller.loadLibrary();
  }

  Future<void> _handleRefresh() async {
    if (_isOffline) {
      AlertBanner.show(
        context,
        'Cannot refresh while offline. Showing cached library.',
        type: AlertBannerType.info,
      );
      await _controller.loadLibrary();
      return;
    }
    await _controller.refresh();
  }

  Future<void> _navigateToMangaDetail(String mangaId, {String? heroTag}) async {
    final cached = await _detailService.getDetail(mangaId);

    if (!mounted) return;

    if (cached != null) {
      await Navigator.pushNamed(
        context,
        AppRoutes.detail,
        arguments: {
          'manga': cached,
          'heroTag': heroTag,
        },
      );
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _controller.loadLibrary();
        });
      }

      if (!_isOffline) {
        _apiService
            .getMangaDetail(mangaId)
            .then((data) {
              final fresh = MangaDetail.fromMap(data);
              _detailService.saveDetail(fresh);
            })
            .catchError((_) {});
      }
      return;
    }

    if (_isOffline) {
      AlertBanner.show(
        context,
        'Manga details are not cached for offline reading.',
        type: AlertBannerType.warning,
      );
      return;
    }

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
      await _detailService.saveDetail(mangaDetail);

      if (!mounted) return;
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
          if (mounted) _controller.loadLibrary();
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

  Future<void> _quickReadManga(LibraryManga manga) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      MangaDetail? detail = _controller.cachedDetails[manga.id];
      detail ??= await _detailService.getDetail(manga.id);

      if (detail == null || detail.chapters.isEmpty) {
        final chaptersData = await _apiService.getMangaChapters(manga.id);
        final chapters = chaptersData.map((e) => Chapter.fromMap(e)).toList();
        detail = (detail ??
            MangaDetail(
              id: manga.id,
              malId: 0,
              title: manga.title,
              author: manga.author,
              type: manga.type,
              popularity: 0,
              members: 0,
              totalView: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              chapters: chapters,
            )).copyWith(chapters: chapters);
      }

      final chapterToRead = detail.chapters.firstWhere(
        (c) => c.chapterNumber == (manga.currentChapter > 0 ? manga.currentChapter : 1.0),
        orElse: () => detail!.chapters.isNotEmpty ? detail.chapters.last : Chapter(
          id: '',
          title: 'Chapter 1',
          chapterNumber: 1,
          date: DateTime.now(),
        ),
      );

      final downloadService = getIt<DownloadService>();
      final downloaded = downloadService.getDownloadedChapter(manga.id, chapterToRead.id);
      List<ChapterPage> pages;
      if (downloaded != null && downloaded.isComplete) {
        pages = downloaded.toChapterPages();
      } else {
        final fetched = await _apiService.getChapterPages(manga.id, chapterToRead.id);
        pages = fetched
            .map((p) => p.copyWith(
                  url: _apiService.getLocalImageUrl(p.url, null),
                ))
            .toList();
      }

      if (!mounted) return;
      Navigator.pop(context);

      final content = ReaderContent(
        mangaId: manga.id,
        mangaTitle: manga.title,
        currentChapterNumber: chapterToRead.chapterNumber,
        chapterId: chapterToRead.id,
        allChapters: detail.chapters,
        chapterTitle: chapterToRead.title,
        pages: pages,
        currentPage: manga.currentPage > 1 ? manga.currentPage : 1,
      );

      await Navigator.pushNamed(context, AppRoutes.reader, arguments: content);
      if (mounted) _controller.loadLibrary();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AlertBanner.show(
          context,
          'Failed to open reader: $e',
          type: AlertBannerType.error,
        );
      }
    }
  }

  Future<void> _changeMangaStatus(LibraryManga manga) async {
    final selected = await StatusSelectionSheet.show(
      context,
      currentStatus: manga.status,
      title: 'Change Status',
    );
    if (selected != null && selected != manga.status) {
      await _controller.updateMangaStatus(manga.id, selected);
      if (mounted) {
        AlertBanner.show(
          context,
          'Status changed to ${StatusSelectionSheet.getLabel(selected)}',
          type: AlertBannerType.success,
        );
      }
    }
  }

  void _showMangaOptionsSheet(LibraryManga manga) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        manga.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  manga.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: manga.isFavorite ? Colors.red : null,
                ),
                title: Text(manga.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                onTap: () {
                  Navigator.pop(context);
                  _controller.toggleMangaFavorite(manga.id);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.bookmark_outline_rounded,
                  color: StatusSelectionSheet.getColor(manga.status),
                ),
                title: Text('Change Status (${StatusSelectionSheet.getLabel(manga.status)})'),
                onTap: () {
                  Navigator.pop(context);
                  _changeMangaStatus(manga);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove from Library', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _controller.removeManga(manga.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineBanner(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offline Mode — Showing cached library',
                style: TextStyle(
                  color: isDark ? Colors.amber[200] : Colors.amber[900],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _handleRefresh,
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
                  expandedHeight: 210,
                  toolbarHeight: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: LibraryHeader(
                          isDark: isDark,
                          selectedStatus: _controller.selectedStatus,
                          showFavoritesOnly: _controller.showFavoritesOnly,
                          isGridView: _controller.isGridView,
                          sortOption: _controller.sortOption,
                          statusCounts: _controller.statusCounts,
                          onSearchChanged: _controller.setSearchQuery,
                          onStatusChanged: _controller.setSelectedStatus,
                          onToggleFavorites: _controller.toggleFavoritesOnly,
                          onToggleViewMode: _controller.toggleViewMode,
                          onSortChanged: _controller.setSortOption,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isOffline) _buildOfflineBanner(isDark),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                  sliver: _buildContent(context, isDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_controller.isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final filteredMangas = _controller.filteredMangas;

    if (filteredMangas.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              _controller.selectedStatus == 'All'
                  ? 'Your library is empty\nAdd some manga to get started!'
                  : 'No manga found with the selected filter',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_controller.isGridView) {
      final screenWidth = MediaQuery.of(context).size.width;
      final crossAxisCount = screenWidth > 900
          ? 5
          : screenWidth > 600
              ? 3
              : 2;

      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.58,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final manga = filteredMangas[index];
          final detail = _controller.cachedDetails[manga.id];
          return LibraryMangaGridCard(
            manga: manga,
            detail: detail,
            isDark: isDark,
            apiService: _apiService,
            onTap: () => _navigateToMangaDetail(
              manga.id,
              heroTag: 'manga-cover-library-grid-${manga.id}',
            ),
            onQuickRead: () => _quickReadManga(manga),
            onLongPress: () => _showMangaOptionsSheet(manga),
            onStatusTap: () => _changeMangaStatus(manga),
          );
        }, childCount: filteredMangas.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final manga = filteredMangas[index];
        final detail = _controller.cachedDetails[manga.id];
        return LibraryMangaCard(
          manga: manga,
          detail: detail,
          isDark: isDark,
          apiService: _apiService,
          onTap: () => _navigateToMangaDetail(
            manga.id,
            heroTag: 'manga-cover-library-list-${manga.id}',
          ),
          onQuickRead: () => _quickReadManga(manga),
          onLongPress: () => _showMangaOptionsSheet(manga),
          onStatusTap: () => _changeMangaStatus(manga),
        );
      }, childCount: filteredMangas.length),
    );
  }
}
