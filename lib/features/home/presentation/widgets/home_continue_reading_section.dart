import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../history/models/progression.dart';
import '../../../manga_detail/models/manga_detail.dart';

class HomeContinueReadingSection extends StatelessWidget {
  final List<MangaProgression> recentProgressions;
  final Map<String, MangaDetail> historyDetailsMap;
  final bool isLoading;
  final bool isDark;
  final MangaApiService apiService;
  final Function(String, {MangaDetail? detail}) onSelectManga;
  final VoidCallback? onNavigateToHistory;

  const HomeContinueReadingSection({
    super.key,
    required this.recentProgressions,
    required this.historyDetailsMap,
    required this.isLoading,
    required this.isDark,
    required this.apiService,
    required this.onSelectManga,
    this.onNavigateToHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading && recentProgressions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Continue Reading',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              if (onNavigateToHistory != null)
                TextButton(
                  onPressed: onNavigateToHistory,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Content
        SizedBox(
          height: 200,
          child: isLoading
              ? _buildSkeletonList()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recentProgressions.length,
                  itemBuilder: (context, index) {
                    final progression = recentProgressions[index];
                    final detail = historyDetailsMap[progression.mangaId];
                    return _buildCard(context, progression, detail);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          width: 140,
          margin: const EdgeInsets.only(right: 14),
          child: const ShimmerBox(
            width: 140,
            height: 200,
            borderRadius: 16,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    MangaProgression progression,
    MangaDetail? detail,
  ) {
    final imageUrl = detail != null
        ? apiService.getLocalImageUrl(detail.localImageUrl, detail.imageUrl)
        : '';
    final title = detail?.title ?? 'Manga #${progression.mangaId}';
    final progress = progression.progressPercentage.clamp(0.0, 1.0);
    final relativeTime = timeAgo(progression.lastRead.toLocal());

    return GestureDetector(
      onTap: () => onSelectManga(progression.mangaId, detail: detail),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? AppColors.slate800.withValues(alpha: 0.9)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Hero(
            tag: 'manga-cover-continue-${progression.mangaId}',
            transitionOnUserGestures: true,
            createRectTween: (begin, end) =>
                MaterialRectArcTween(begin: begin, end: end),
            flightShuttleBuilder: (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) {
              return Material(
                color: Colors.transparent,
                child: toHeroContext.widget,
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 450,
                        maxWidthDiskCache: 600,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, _) => Container(
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
                        ),
                        errorBuilder: (_, _, _) => Container(
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.25, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      relativeTime,
                      style: const TextStyle(
                        color: Colors.white,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
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
                              child: Text(
                                'Ch. ${progression.currentChapter % 1 == 0 ? progression.currentChapter.toInt() : progression.currentChapter}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                            minHeight: 3,
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
      ),
    );
  }
}
