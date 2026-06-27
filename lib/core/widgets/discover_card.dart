import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../data/models/manga_summary.dart';
import '../../data/services/manga_api_service.dart';
import '../di/injection.dart';

class DiscoverCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? localImageUrl;
  final String type;
  final String views;
  final LatestChapterSummary? latestChapter;
  final List<String> genres;
  final String? status;
  final double? rating;
  final VoidCallback? onTap;

  const DiscoverCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.localImageUrl,
    required this.type,
    required this.views,
    required this.latestChapter,
    required this.genres,
    this.status,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String displayUrl = getIt<MangaApiService>().getLocalImageUrl(
      localImageUrl,
      imageUrl,
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Responsive dimensions
    final double borderRadius = isDesktop
        ? 16
        : isTablet
        ? 14
        : 12;

    final double titleFontSize = isDesktop
        ? 16
        : isTablet
        ? 15
        : 14;

    final double genreFontSize = isDesktop
        ? 11
        : isTablet
        ? 10.5
        : 10;

    final double statusFontSize = isDesktop
        ? 10
        : isTablet
        ? 9.5
        : 9;
    final double ratingFontSize = isDesktop
        ? 10
        : isTablet
        ? 9.5
        : 9;

    final double typeFontSize = isDesktop
        ? 11
        : isTablet
        ? 10.5
        : 10;

    final double chapterFontSize = isDesktop
        ? 11
        : isTablet
        ? 10.5
        : 10;

    final double viewsFontSize = isDesktop
        ? 11
        : isTablet
        ? 10.5
        : 10;

    final double iconSize = isDesktop
        ? 14
        : isTablet
        ? 13
        : 12;

    final EdgeInsetsGeometry statusPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : isTablet
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 3);

    final EdgeInsetsGeometry ratingPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : isTablet
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 3);

    final EdgeInsetsGeometry typePadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : isTablet
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    final EdgeInsetsGeometry chapterPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
        : isTablet
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 2);

    final EdgeInsetsGeometry viewsPadding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
        : isTablet
        ? const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 2);

    final double placeholderIconSize = isDesktop
        ? 40
        : isTablet
        ? 36
        : 32;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: isDesktop
                        ? 12
                        : isTablet
                        ? 11
                        : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (displayUrl.isNotEmpty)
                      Image.network(
                        displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholder(placeholderIconSize),
                      )
                    else
                      _buildPlaceholder(placeholderIconSize),

                    // Top Right Badges (Status & Rating)
                    Positioned(
                      top: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      right: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (status != null && status!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: statusPadding,
                              decoration: BoxDecoration(
                                color: status?.toLowerCase() == 'ongoing'
                                    ? Colors.green.withOpacity(0.8)
                                    : status?.toLowerCase() == 'completed' ||
                                          status?.toLowerCase() == 'finished' ||
                                          status?.toLowerCase() == 'end'
                                    ? Colors.blue.withOpacity(0.8)
                                    : Colors.orange.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status!.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: statusFontSize,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Container(
                            padding: ratingPadding,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: iconSize + 2,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  (rating == null || rating == 0)
                                      ? 'N/A'
                                      : rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: ratingFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Type Badge (Manga/Manhwa/Manhua)
                    Positioned(
                      top: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      left: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      child: Container(
                        padding: typePadding,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: typeFontSize,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Badges
                    Positioned(
                      bottom: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      left: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      right: isDesktop
                          ? 12
                          : isTablet
                          ? 10
                          : 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: chapterPadding,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ch. ${latestChapter?.number.toInt() ?? 0}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: chapterFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: viewsPadding,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  views,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: viewsFontSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            genres.join(', '),
            style: TextStyle(fontSize: genreFontSize, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(double iconSize) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.primary.withOpacity(0.5),
          size: iconSize,
        ),
      ),
    );
  }
}
