import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../manga_detail/models/manga_detail.dart';
import '../../../manga_detail/presentation/widgets/status_selection_sheet.dart';
import '../../models/library_manga.dart';

class LibraryMangaCard extends StatelessWidget {
  final LibraryManga manga;
  final MangaDetail? detail;
  final bool isDark;
  final MangaApiService apiService;
  final VoidCallback onTap;
  final VoidCallback? onQuickRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onStatusTap;

  const LibraryMangaCard({
    super.key,
    required this.manga,
    required this.detail,
    required this.isDark,
    required this.apiService,
    required this.onTap,
    this.onQuickRead,
    this.onLongPress,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final String displayUrl = apiService.getLocalImageUrl(
      detail?.localImageUrl ?? manga.imageUrl,
      manga.imageUrl,
    );

    final String displayAuthor = (detail != null &&
            detail!.author.isNotEmpty &&
            detail!.author != 'Unknown Author')
        ? detail!.author
        : manga.author;

    final String displayDescription = (detail?.description != null &&
            detail!.description!.isNotEmpty &&
            detail!.description != 'No description available')
        ? detail!.description!
        : (manga.manga?.description != null && manga.manga!.description!.isNotEmpty)
            ? manga.manga!.description!
            : '';

    final String displayType = detail?.type.isNotEmpty == true
        ? detail!.type
        : manga.type.isNotEmpty
            ? manga.type
            : (manga.manga?.type ?? 'Manga');

    final double? rating = detail?.rating ?? manga.manga?.rating;
    final List<String> genres = (detail?.genres != null && detail!.genres!.isNotEmpty)
        ? detail!.genres!
        : (manga.manga?.genres != null && manga.manga!.genres!.isNotEmpty)
            ? manga.manga!.genres!
            : [];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image Left with Hero Morph
                Hero(
                  tag: 'manga-cover-library-list-${manga.id}',
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
                    children: [
                      Container(
                        width: 110,
                        height: 165,
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: displayUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: displayUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 300,
                                maxWidthDiskCache: 500,
                                errorBuilder: (context, url, error) =>
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
                          color: Colors.black.withValues(alpha: 0.2),
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
                      if (manga.isFavorite)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Information details Right
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    manga.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (rating != null && rating > 0) ...[
                                  const SizedBox(width: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayAuthor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (isDark ? Colors.white70 : Colors.black54)
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                if (displayType.isNotEmpty && displayType != 'Unknown')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      displayType.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (genres.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: genres.take(3).map((g) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: (isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (displayDescription.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                displayDescription,
                                maxLines: genres.isNotEmpty ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (isDark ? Colors.white60 : Colors.black45),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Bottom badges & Quick Action
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (manga.hasStartedReading)
                                  Text(
                                    'Ch. ${manga.currentChapter % 1 == 0 ? manga.currentChapter.toInt() : manga.currentChapter} (Pg. ${manga.currentPage})',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  Text(
                                    'Not Started',
                                    style: TextStyle(
                                      color: Colors.grey.withValues(alpha: 0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                const SizedBox(height: 3),
                                GestureDetector(
                                  onTap: onStatusTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: StatusSelectionSheet.getColor(manga.status)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: StatusSelectionSheet.getColor(manga.status)
                                            .withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          StatusSelectionSheet.getLabel(manga.status),
                                          style: TextStyle(
                                            color: StatusSelectionSheet.getColor(manga.status),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: StatusSelectionSheet.getColor(manga.status),
                                          size: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (onQuickRead != null)
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  tooltip: 'Continue Reading',
                                  icon: Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  onPressed: onQuickRead,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: EdgeInsets.zero,
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
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white30, size: 28),
      ),
    );
  }
}
