import 'dart:ui';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/manga_summary.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_box.dart';

class HomeTopMangaSection extends StatelessWidget {
  final List<MangaSummary> topManga;
  final bool isLoading;
  final bool isDark;
  final MangaApiService apiService;
  final void Function(String mangaId, {MangaSummary? summary}) onSelectManga;
  final VoidCallback onNavigateToDiscover;

  const HomeTopMangaSection({
    super.key,
    required this.topManga,
    required this.isLoading,
    this.isDark = true,
    required this.apiService,
    required this.onSelectManga,
    required this.onNavigateToDiscover,
  });

  @override
  Widget build(BuildContext context) {
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
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Top Manga',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👑 TOP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onNavigateToDiscover,
                child: Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Carousel content
        if (isLoading)
          _buildSkeletonLoader()
        else if (topManga.isEmpty)
          _buildEmptyState()
        else
          SizedBox(
            height: 255,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topManga.length,
              itemBuilder: (context, index) {
                return _TopMangaCard(
                  manga: topManga[index],
                  rank: index,
                  isDark: isDark,
                  apiService: apiService,
                  onTap: () => onSelectManga(
                    topManga[index].id,
                    summary: topManga[index],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return SizedBox(
      height: 255,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 156,
            margin: const EdgeInsets.only(right: 14),
            child: const ShimmerBox(
              width: 156,
              height: 255,
              borderRadius: 16,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 32,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No top manga found',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMangaCard extends StatefulWidget {
  final MangaSummary manga;
  final int rank;
  final bool isDark;
  final MangaApiService apiService;
  final VoidCallback onTap;

  const _TopMangaCard({
    required this.manga,
    required this.rank,
    required this.isDark,
    required this.apiService,
    required this.onTap,
  });

  @override
  State<_TopMangaCard> createState() => _TopMangaCardState();
}

class _TopMangaCardState extends State<_TopMangaCard> {
  bool _isHovered = false;

  Color _getTypeColor(String type) {
    return switch (type.toLowerCase()) {
      'manhwa' => const Color(0xFF8B5CF6),
      'manhua' => const Color(0xFF06B6D4),
      'novel' => const Color(0xFFF59E0B),
      _ => AppColors.primary,
    };
  }

  String _formatChapterNumber(double number) {
    return number % 1 == 0 ? number.toInt().toString() : number.toString();
  }

  Color _getRankGlowColor(int rank) {
    return switch (rank) {
      0 => const Color(0xFFF59E0B),
      1 => const Color(0xFF94A3B8),
      2 => const Color(0xFFD97706),
      _ => Colors.black,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.apiService.getLocalImageUrl(
      widget.manga.localImageUrl,
      widget.manga.imageUrl,
    );
    final heroTag = 'manga-cover-top-${widget.manga.id}';
    final rankGlow = _getRankGlowColor(widget.rank);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 156,
          margin: const EdgeInsets.only(right: 14),
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Card with Cover Image and Shadows
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: _isHovered ? 0.2 : 0.08)
                        : Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rankGlow.withValues(
                        alpha: widget.rank < 3
                            ? (_isHovered ? 0.32 : 0.20)
                            : (_isHovered ? 0.25 : 0.14),
                      ),
                      blurRadius: _isHovered ? 18 : 12,
                      offset: Offset(0, _isHovered ? 8 : 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.isDark ? 0.35 : 0.12,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Hero(
                  tag: heroTag,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Manga Cover Image
                        imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 400,
                                maxWidthDiskCache: 600,
                                fadeInDuration:
                                    const Duration(milliseconds: 200),
                                placeholder: (_, _) => const ShimmerBox(
                                  borderRadius: 16,
                                ),
                                errorBuilder: (_, _, _) => Container(
                                  color: widget.isDark
                                      ? Colors.grey[850]
                                      : Colors.grey[200],
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : Container(
                                color: widget.isDark
                                    ? Colors.grey[850]
                                    : Colors.grey[200],
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              ),

                        // Gradient Scrim Vignette
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.25, 0.45, 0.70, 1.0],
                                colors: [
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.black.withValues(alpha: 0.95),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Bottom Overlay Content
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
                                // Type badge & First Genre
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(widget.manga.type)
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        widget.manga.type.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                    if (widget.manga.genres != null &&
                                        widget.manga.genres!.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                              width: 0.5,
                                            ),
                                          ),
                                          child: Text(
                                            widget.manga.genres!.first,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),

                                // Title
                                Text(
                                  widget.manga.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.25,
                                    letterSpacing: 0.1,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Latest Chapter & Views Badges
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Latest Chapter Pill
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.menu_book_rounded,
                                              size: 10,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                widget.manga.latestChapter != null
                                                    ? 'Ch. ${_formatChapterNumber(widget.manga.latestChapter!.number)}'
                                                    : 'Ch. -',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // View Count Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.15),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.remove_red_eye_outlined,
                                            size: 10.5,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            formatViewCount(
                                                widget.manga.totalView),
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 9.5,
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Rank Badge (Top Left)
              Positioned(
                top: 9,
                left: 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: widget.rank == 0
                            ? const LinearGradient(
                                colors: [Color(0xFFFFB800), Color(0xFFD97706)],
                              )
                            : widget.rank == 1
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFCBD5E1),
                                      Color(0xFF64748B)
                                    ],
                                  )
                                : widget.rank == 2
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFDBA74),
                                          Color(0xFFC2410C)
                                        ],
                                      )
                                    : null,
                        color: widget.rank >= 3
                            ? Colors.black.withValues(alpha: 0.6)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.rank < 3
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.rank == 0)
                            const Text('🥇', style: TextStyle(fontSize: 10))
                          else if (widget.rank == 1)
                            const Text('🥈', style: TextStyle(fontSize: 10))
                          else if (widget.rank == 2)
                            const Text('🥉', style: TextStyle(fontSize: 10))
                          else
                            Text(
                              '#${widget.rank + 1}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          if (widget.rank < 3) ...[
                            const SizedBox(width: 3),
                            Text(
                              '#${widget.rank + 1}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Rating Badge (Top Right)
              Positioned(
                top: 9,
                right: 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFC107),
                            size: 13,
                          ),
                          const SizedBox(width: 2.5),
                          Text(
                            (widget.manga.rating == null ||
                                    widget.manga.rating == 0)
                                ? 'N/A'
                                : widget.manga.rating!.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
