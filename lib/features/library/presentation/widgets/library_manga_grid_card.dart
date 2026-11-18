import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../manga_detail/models/manga_detail.dart';
import '../../../manga_detail/presentation/widgets/status_selection_sheet.dart';
import '../../models/library_manga.dart';

class LibraryMangaGridCard extends StatelessWidget {
  final LibraryManga manga;
  final MangaDetail? detail;
  final bool isDark;
  final MangaApiService apiService;
  final VoidCallback onTap;
  final VoidCallback? onQuickRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onStatusTap;

  const LibraryMangaGridCard({
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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900]!.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image with Hero Morph
              Expanded(
                child: Hero(
                  tag: 'manga-cover-library-grid-${manga.id}',
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
                      displayUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: displayUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 350,
                              maxWidthDiskCache: 500,
                              errorBuilder: (context, url, error) =>
                                  Container(color: Colors.grey[850]),
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[850]),
                            )
                          : Container(color: Colors.grey[850]),
                      // Gradient overlay
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Progress percentage bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: Colors.black.withValues(alpha: 0.3),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: manga.progressPercentage.clamp(0.0, 1.0),
                            child: Container(color: AppColors.primary),
                          ),
                        ),
                      ),
                      if (manga.isFavorite)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
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
                      // Rating / Type badge top left
                      if ((detail?.rating ?? manga.manga?.rating) != null &&
                          (detail?.rating ?? manga.manga?.rating)! > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  (detail?.rating ?? manga.manga?.rating)!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (manga.hasStartedReading)
                        Positioned(
                          bottom: 6,
                          left: 8,
                          child: Text(
                            'Ch. ${manga.currentChapter % 1 == 0 ? manga.currentChapter.toInt() : manga.currentChapter}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Manga Info
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            manga.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        ),
                        if (manga.type.isNotEmpty && manga.type != 'Unknown')
                          Text(
                            manga.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onStatusTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: StatusSelectionSheet.getColor(manga.status)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
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
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: StatusSelectionSheet.getColor(manga.status),
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
