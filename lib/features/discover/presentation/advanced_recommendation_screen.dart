import 'package:material_ui/material_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/widgets/discover_card.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/models/manga_summary.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../routes/app_pages.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../models/advanced_recommendation_request.dart';
import 'widgets/discover_grid_skeleton.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

class AdvancedRecommendationScreen extends StatefulWidget {
  const AdvancedRecommendationScreen({super.key});

  @override
  State<AdvancedRecommendationScreen> createState() =>
      _AdvancedRecommendationScreenState();
}

class _AdvancedRecommendationScreenState
    extends State<AdvancedRecommendationScreen> {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final ProgressionService _progressionService = getIt<ProgressionService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();

  List<MangaProgression> _history = [];
  Map<String, MangaDetail> _historyDetailsMap = {};
  final Set<String> _likedIds = {};
  final Set<String> _dislikedIds = {};

  List<MangaSummary> _results = [];
  bool _isLoadingHistory = true;
  bool _isLoadingResults = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final progressions = await _progressionService.getAllProgressions();
      progressions.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
      final recent = progressions.take(20).toList();

      final detailsMap = <String, MangaDetail>{};
      final fetchFutures = recent.map((p) async {
        if (p.manga != null) {
          return MapEntry(p.mangaId, MangaDetail.fromMangaSummary(p.manga!));
        }
        try {
          final cached = await _detailService.getDetail(p.mangaId);
          if (cached != null) {
            return MapEntry(p.mangaId, cached);
          } else {
            final data = await _apiService.getMangaDetail(p.mangaId);
            final detail = MangaDetail.fromMap(data);
            await _detailService.saveDetail(detail);
            return MapEntry(p.mangaId, detail);
          }
        } catch (_) {
          return null;
        }
      });

      final loadedEntries = await Future.wait(fetchFutures);
      for (final entry in loadedEntries) {
        if (entry != null) {
          detailsMap[entry.key] = entry.value;
        }
      }

      if (mounted) {
        setState(() {
          _history = recent;
          _historyDetailsMap = detailsMap;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _getRecommendations() async {
    if (_likedIds.isEmpty && _dislikedIds.isEmpty) {
      AlertBanner.show(
        context,
        'Please like or dislike at least one manga to guide the AI.',
        type: AlertBannerType.info,
      );
      return;
    }

    setState(() {
      _isLoadingResults = true;
      _results.clear();
    });

    try {
      final request = AdvancedRecommendationRequest(
        likedIds: _likedIds.toList(),
        dislikedIds: _dislikedIds.toList(),
        limit: 20,
      );

      final items = await _apiService.getAdvancedRecommendations(request);

      if (mounted) {
        setState(() {
          _results = items;
          _isLoadingResults = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingResults = false);
        AlertBanner.show(
          context,
          'Failed to load recommendations: $e',
          type: AlertBannerType.error,
        );
      }
    }
  }

  void _navigateToDetail(MangaSummary item) async {
    final heroTag = 'manga-cover-airec-${item.id}';
    // Fast path: Check local cache first
    try {
      final cached = await _detailService.getDetail(item.id);
      if (cached != null && mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        await Navigator.pushNamed(
          context,
          AppRoutes.detail,
          arguments: {
            'manga': cached,
            'heroTag': heroTag,
          },
        );
        return;
      }
    } catch (_) {}

    // Fallback: Show loading dialog and fetch
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final detailData = await _apiService.getMangaDetail(item.id);
      if (mounted) {
        Navigator.pop(context);
        final mangaDetail = MangaDetail.fromMap(detailData);
        await _detailService.saveDetail(mangaDetail);
        if (mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.detail,
            arguments: {
              'manga': mangaDetail,
              'heroTag': heroTag,
            },
          );
        }
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

  void _toggleLike(String id) {
    setState(() {
      if (_likedIds.contains(id)) {
        _likedIds.remove(id);
      } else {
        _likedIds.add(id);
        _dislikedIds.remove(id);
      }
    });
  }

  void _toggleDislike(String id) {
    setState(() {
      if (_dislikedIds.contains(id)) {
        _dislikedIds.remove(id);
      } else {
        _dislikedIds.add(id);
        _likedIds.remove(id);
      }
    });
  }

  void _clearAllSelections() {
    setState(() {
      _likedIds.clear();
      _dislikedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          'AI Recommendations',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_likedIds.isNotEmpty || _dislikedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllSelections,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: _isLoadingHistory
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.slate700.withValues(alpha: 0.25)
                        : Colors.grey.withValues(alpha: 0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select from your reading history:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (_likedIds.isNotEmpty || _dislikedIds.isNotEmpty)
                            Text(
                              '${_likedIds.length} 👍 • ${_dislikedIds.length} 👎',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 145,
                        child: _history.isEmpty
                            ? const Center(
                                child: Text('No reading history found.'),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final item = _history[index];
                                  final isLiked = _likedIds.contains(
                                    item.mangaId,
                                  );
                                  final isDisliked = _dislikedIds.contains(
                                    item.mangaId,
                                  );

                                  return Container(
                                    width: 90,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.cardDark
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isLiked
                                            ? Colors.green
                                            : isDisliked
                                            ? Colors.red
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (_historyDetailsMap[item.mangaId] !=
                                              null)
                                            CachedNetworkImage(
                                              imageUrl: _apiService
                                                  .getLocalImageUrl(
                                                _historyDetailsMap[item.mangaId]!
                                                    .localImageUrl,
                                                _historyDetailsMap[item.mangaId]!
                                                    .imageUrl,
                                              ),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            )
                                          else
                                            const Center(
                                              child: Icon(
                                                Icons.image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withValues(
                                                    alpha: 0.2,
                                                  ),
                                                  Colors.black.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            left: 4,
                                            right: 4,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () => _toggleLike(item.mangaId),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: isLiked
                                                          ? Colors.green
                                                          : Colors.black45,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.thumb_up,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () => _toggleDislike(item.mangaId),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: isDisliked
                                                          ? Colors.red
                                                          : Colors.black45,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.thumb_down,
                                                      size: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 6,
                                            left: 4,
                                            right: 4,
                                            child: Text(
                                              _historyDetailsMap[item.mangaId]
                                                      ?.title ??
                                                  'Loading...',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingResults ? null : _getRecommendations,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isLoadingResults
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            _likedIds.isEmpty && _dislikedIds.isEmpty
                                ? 'Select Manga to Generate'
                                : 'Generate (${_likedIds.length} Liked • ${_dislikedIds.length} Disliked)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoadingResults
                      ? DiscoverGridSkeleton(
                          itemCount: 6,
                          gridDelegate: _buildGridDelegate(),
                        )
                      : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.psychology_alt_outlined,
                                  size: 56,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Ready for AI Recommendations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Like titles you enjoyed and dislike ones you did not to generate personalized picks.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
                          gridDelegate: _buildGridDelegate(),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            return DiscoverCard(
                              title: item.title,
                              type: item.type,
                              latestChapter: item.latestChapter,
                              views: formatViewCount(item.totalView),
                              genres: item.genres ?? [],
                              status: item.status,
                              rating: item.rating,
                              heroTag: 'manga-cover-airec-${item.id}',
                              imageUrl: _apiService.getLocalImageUrl(
                                item.localImageUrl,
                                item.imageUrl,
                              ),
                              onTap: () => _navigateToDetail(item),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
