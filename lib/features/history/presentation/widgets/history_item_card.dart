import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../manga_detail/models/manga_detail.dart';
import '../../models/progression.dart';

class HistoryItemCard extends StatelessWidget {
  final MangaProgression progression;
  final MangaDetail? mangaDetail;
  final bool isDark;
  final MangaApiService apiService;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const HistoryItemCard({
    super.key,
    required this.progression,
    required this.mangaDetail,
    required this.isDark,
    required this.apiService,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = progression.manga?.title ??
        mangaDetail?.title ??
        'Manga #${progression.mangaId}';

    final localImage = progression.manga?.localImageUrl ??
        mangaDetail?.localImageUrl;
    final remoteImage = progression.manga?.imageUrl ?? mangaDetail?.imageUrl;
    final imageUrl = apiService.getLocalImageUrl(localImage, remoteImage);

    final progress = progression.progressPercentage;
    final relativeTime = timeAgo(progression.lastRead.toLocal());
    final readingTime = progression.formattedTotalReadingTime;

    return Dismissible(
      key: ValueKey('history_${progression.mangaId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        onDelete?.call();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.slate800.withValues(alpha: 0.85)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Manga Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 76,
                    height: 106,
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 250,
                            maxWidthDiskCache: 400,
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
                  ),
                ),
                const SizedBox(width: 14),

                // Content details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // Chapter & Page info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Ch. ${progression.currentChapter.toInt()}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Page ${progression.currentPage}/${progression.totalPages}',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (readingTime.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•  $readingTime',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Footer: Relative time & completion badge
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            relativeTime,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          if (progression.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
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

