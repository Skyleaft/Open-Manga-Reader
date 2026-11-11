import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/manga_summary.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/shimmer_box.dart';

class HomeLatestUpdatesSection extends StatelessWidget {
  final List<MangaSummary> latestUpdates;
  final bool isLoading;
  final bool isDark;
  final MangaApiService apiService;
  final void Function(String mangaId, {MangaSummary? summary}) onSelectManga;
  final VoidCallback onNavigateToDiscover;

  const HomeLatestUpdatesSection({
    super.key,
    required this.latestUpdates,
    required this.isLoading,
    this.isDark = true,
    required this.apiService,
    required this.onSelectManga,
    required this.onNavigateToDiscover,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
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
                        colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Latest Updates',
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
                        colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '⚡ NEW',
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
          const SizedBox(height: 14),

          // Items Content
          if (isLoading)
            _buildSkeletonLoader()
          else if (latestUpdates.isEmpty)
            _buildEmptyState()
          else
            ...latestUpdates.map(
              (manga) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LatestUpdateCard(
                  manga: manga,
                  isDark: isDark,
                  apiService: apiService,
                  onTap: () => onSelectManga(manga.id, summary: manga),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.035)
                  : Colors.black.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: const Row(
              children: [
                ShimmerBox(
                  width: 68,
                  height: 94,
                  borderRadius: 12,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShimmerBox(width: 50, height: 12, borderRadius: 4),
                          SizedBox(width: 8),
                          ShimmerBox(width: 40, height: 10, borderRadius: 4),
                        ],
                      ),
                      SizedBox(height: 10),
                      ShimmerBox(width: 160, height: 14, borderRadius: 4),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          ShimmerBox(width: 70, height: 18, borderRadius: 6),
                          SizedBox(width: 10),
                          ShimmerBox(width: 45, height: 12, borderRadius: 4),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
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
              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.update_disabled_rounded,
              size: 32,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No updates found',
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

class _LatestUpdateCard extends StatefulWidget {
  final MangaSummary manga;
  final bool isDark;
  final MangaApiService apiService;
  final VoidCallback onTap;

  const _LatestUpdateCard({
    required this.manga,
    required this.isDark,
    required this.apiService,
    required this.onTap,
  });

  @override
  State<_LatestUpdateCard> createState() => _LatestUpdateCardState();
}

class _LatestUpdateCardState extends State<_LatestUpdateCard> {
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

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.apiService.getLocalImageUrl(
      widget.manga.localImageUrl,
      widget.manga.imageUrl,
    );
    final heroTag = 'manga-cover-latest-${widget.manga.id}';

    final uploadDate =
        widget.manga.latestChapter?.uploadDate ?? widget.manga.updatedAt;
    final timeStr = timeAgo(uploadDate);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: _isHovered ? 0.07 : 0.035)
                : Colors.black.withValues(alpha: _isHovered ? 0.05 : 0.025),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: _isHovered ? 0.16 : 0.07)
                  : Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isDark
                      ? (_isHovered ? 0.35 : 0.18)
                      : (_isHovered ? 0.12 : 0.05),
                ),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover Image Container
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: widget.isDark ? 0.4 : 0.2,
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
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 68,
                          height: 94,
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 250,
                                  maxWidthDiskCache: 450,
                                  fadeInDuration:
                                      const Duration(milliseconds: 200),
                                  placeholder: (_, _) => const ShimmerBox(
                                    borderRadius: 12,
                                  ),
                                  errorBuilder: (_, _, _) => Container(
                                    color: widget.isDark
                                        ? Colors.grey[850]
                                        : Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey,
                                      size: 20,
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
                                    size: 20,
                                  ),
                                ),
                        ),
                        // Rating Badge Overlay
                        if (widget.manga.rating != null &&
                            widget.manga.rating! > 0)
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFC107),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 1.5),
                                  Text(
                                    widget.manga.rating!.toStringAsFixed(1),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
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

              // Content Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top row: Type badge + First genre + Time ago
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(widget.manga.type)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
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
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.manga.genres!.first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: widget.isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (timeStr.isNotEmpty) ...[
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        widget.manga.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom row: Chapter Pill + Views count
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
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 11,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.manga.latestChapter != null
                                      ? 'Ch. ${_formatChapterNumber(widget.manga.latestChapter!.number)}'
                                      : 'Ch. -',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 12,
                                color: widget.isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formatViewCount(widget.manga.totalView),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  color: widget.isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action Chevron
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: widget.isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
