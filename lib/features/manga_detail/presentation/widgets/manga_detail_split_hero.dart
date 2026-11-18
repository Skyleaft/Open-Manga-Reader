import 'package:material_ui/material_ui.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/manga_detail.dart';
import 'manga_cover_dialog.dart';

class MangaDetailSplitHero extends StatelessWidget {
  final MangaDetail manga;
  final String heroImageUrl;
  final int chapterCount;
  final bool isDark;
  final String? heroTag;
  final bool isHeroVisible;
  final VoidCallback? onCoverTap;

  const MangaDetailSplitHero({
    super.key,
    required this.manga,
    required this.heroImageUrl,
    this.chapterCount = 0,
    required this.isDark,
    this.heroTag,
    this.isHeroVisible = true,
    this.onCoverTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final double posterWidth = isDesktop ? 200 : (isTablet ? 160 : 140);
    final double posterHeight = isDesktop ? 270 : (isTablet ? 210 : 190);
    final double titleFontSize = isDesktop ? 26 : (isTablet ? 22 : 18.5);

    final colorScheme = Theme.of(context).colorScheme;
    final typeStr = manga.type.isNotEmpty ? manga.type.toUpperCase() : 'MANGA';
    final statusStr = manga.status?.toUpperCase() ?? 'ONGOING';
    final isCompleted = statusStr.contains('COMPLETE');
    final actualChapters = chapterCount > 0
        ? chapterCount
        : manga.chapters.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left: Poster Cover Card with Hero Morph
        HeroMode(
          enabled: isHeroVisible,
          child: Hero(
            tag: heroTag ?? 'manga-detail-poster-${manga.id}',
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
              final Widget flyingWidget =
                  flightDirection == HeroFlightDirection.pop
                      ? fromHeroContext.widget
                      : toHeroContext.widget;
              return Material(
                color: Colors.transparent,
                child: flyingWidget,
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (onCoverTap != null) {
                    onCoverTap!();
                  } else {
                    MangaCoverViewer.show(
                      context,
                      manga: manga,
                      heroImageUrl: heroImageUrl,
                      heroTag: heroTag,
                    );
                  }
                },
                child: Tooltip(
                  message: 'View full screen cover',
                  child: Container(
                    width: posterWidth,
                    height: posterHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.55 : 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: heroImageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: heroImageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 400,
                                  maxWidthDiskCache: 600,
                                  placeholder: (_, _) => Container(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                  errorBuilder: (_, _, _) => Container(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.grey[300],
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black45,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.grey[300],
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black45,
                                    size: 32,
                                  ),
                                ),
                        ),
                        // Sleek fullscreen indicator badge
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(width: isDesktop ? 22 : (isTablet ? 18 : 16)),

        // Right: Badges, Title, Author, Quick Stats Meta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type & Status Badges
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 10 : 8,
                      vertical: isDesktop ? 4.5 : 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      typeStr,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isDesktop ? 11 : 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 10 : 8,
                      vertical: isDesktop ? 4.5 : 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isCompleted
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B))
                                  .withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      statusStr,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: isDesktop ? 11 : 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isDesktop ? 10 : 8),

              // Title
              Text(
                manga.title,
                maxLines: isDesktop ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  shadows: isDark
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 6,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
              ),

              const SizedBox(height: 6),

              // Author
              if (manga.author.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: isDesktop ? 16 : 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        manga.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isDesktop ? 14 : 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

              SizedBox(height: isDesktop ? 12 : 8),

              // Quick Stats Meta Row (Rating, Chapters, Views, Release Year)
              Wrap(
                spacing: isDesktop ? 8 : 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (manga.rating != null && manga.rating! > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 9 : 7,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: const Color(0xFFFBBF24),
                            size: isDesktop ? 16 : 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            manga.rating!.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (actualChapters > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 9 : 7,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            color: colorScheme.primary,
                            size: isDesktop ? 15 : 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$actualChapters Chs',
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (manga.totalView > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 9 : 7,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: isDesktop ? 15 : 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatViewCount(manga.totalView),
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (manga.releaseDate != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 9 : 7,
                        vertical: isDesktop ? 4 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: const Color(0xFF60A5FA),
                            size: isDesktop ? 14 : 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy').format(manga.releaseDate!),
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: isDesktop ? 12 : 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
