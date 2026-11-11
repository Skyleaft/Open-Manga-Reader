import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../models/manga_detail.dart';
import 'manga_detail_split_hero.dart';

class MangaDetailAppBar extends StatelessWidget {
  final MangaDetail manga;
  final String heroImageUrl;
  final int chapterCount;
  final String? heroTag;
  final VoidCallback? onCoverTap;

  const MangaDetailAppBar({
    super.key,
    required this.manga,
    required this.heroImageUrl,
    this.chapterCount = 0,
    this.heroTag,
    this.onCoverTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double expandedBarHeight = isDesktop
        ? 450.0
        : (isTablet ? 410.0 : 380.0);
    const double collapsedToolbarHeight = 68.0;

    return SliverAppBar(
      expandedHeight: expandedBarHeight,
      toolbarHeight: collapsedToolbarHeight,
      floating: false,
      pinned: true,
      snap: false,
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 64,
      leading: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _GlassCircleButton(
            icon: Icons.arrow_back_rounded,
            iconSize: 20,
            tooltip: 'Back',
            isDark: isDark,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _GlassCircleButton(
              icon: Icons.share_rounded,
              iconSize: 19,
              tooltip: 'Share Manga',
              isDark: isDark,
              onPressed: () {
                final baseUrl = AppConfig.baseUrl;
                final webShareUrl = '$baseUrl/manga/${manga.id}';
                final customSchemeUrl =
                    'open-manga-reader://manga/${manga.id}';
                final shareText =
                    'Read ${manga.title} on Open Manga Reader!\n\n'
                    'Web link: $webShareUrl\n'
                    'Or open in app: $customSchemeUrl';

                // ignore: deprecated_member_use
                Share.share(shareText, subject: 'Share ${manga.title}');
              },
            ),
          ),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final isCollapsed =
              top <=
              (collapsedToolbarHeight +
                  MediaQuery.of(context).padding.top +
                  15);

          final isHeroVisible = top > 200;

          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                titlePadding: const EdgeInsets.only(
                  left: 64,
                  right: 64,
                  bottom: 14,
                ),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (heroImageUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: onCoverTap,
                          child: MouseRegion(
                            cursor: onCoverTap != null
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                            child: Tooltip(
                              message: 'View cover',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.1),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.4 : 0.15,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5.2),
                                  child: CachedNetworkImage(
                                    imageUrl: heroImageUrl,
                                    width: 30,
                                    height: 42,
                                    memCacheWidth: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              manga.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (manga.author.isNotEmpty)
                              Text(
                                manga.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.55),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                background: _buildParallaxBackdropAndHero(
                  context,
                  isDark,
                  isHeroVisible: isHeroVisible,
                ),
              ),

              // Hairline bottom divider visible only when collapsed
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Container(
                    height: 0.8,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParallaxBackdropAndHero(
    BuildContext context,
    bool isDark, {
    required bool isHeroVisible,
  }) {
    final bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Atmospheric Ambient Blurred Backdrop (Scaled slightly to prevent edge vignette bleeding)
        if (heroImageUrl.isNotEmpty)
          RepaintBoundary(
            child: ClipRect(
              child: Transform.scale(
                scale: 1.08,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: CachedNetworkImage(
                    imageUrl: heroImageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 80,
                    maxWidthDiskCache: 300,
                    filterQuality: FilterQuality.low,
                    placeholder: (_, _) => Container(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey[300],
                    ),
                    errorBuilder: (_, _, _) => Container(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey[300],
          ),

        // Deep Cinematic Vignette Gradient with smooth multi-stop transition
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.28, 0.58, 0.84, 1.0],
                colors: [
                  Colors.black.withValues(alpha: isDark ? 0.72 : 0.42),
                  Colors.black.withValues(alpha: isDark ? 0.38 : 0.16),
                  bgColor.withValues(alpha: 0.55),
                  bgColor.withValues(alpha: 0.92),
                  bgColor,
                ],
              ),
            ),
          ),
        ),

        // Split Hero centered within max width constraints
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: MangaDetailSplitHero(
                  manga: manga,
                  heroImageUrl: heroImageUrl,
                  chapterCount: chapterCount,
                  isDark: isDark,
                  heroTag: heroTag,
                  isHeroVisible: isHeroVisible,
                  onCoverTap: onCoverTap,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glassmorphic circular action button with frosted glass backdrop blur and hover animation
class _GlassCircleButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String? tooltip;
  final VoidCallback onPressed;
  final bool isDark;

  const _GlassCircleButton({
    required this.icon,
    this.iconSize = 20,
    this.tooltip,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? (_isHovered
            ? Colors.white.withValues(alpha: 0.20)
            : const Color(0x730F172A))
        : (_isHovered
            ? Colors.white.withValues(alpha: 0.98)
            : const Color(0xD9FFFFFF));

    final borderColor = widget.isDark
        ? (_isHovered
            ? Colors.white.withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.14))
        : (_isHovered
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.08));

    final iconColor = widget.isDark
        ? Colors.white
        : const Color(0xFF0F172A);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? 0.35 : 0.10,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: widget.tooltip,
                icon: Icon(
                  widget.icon,
                  color: iconColor,
                  size: widget.iconSize,
                ),
                onPressed: widget.onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
