import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/haptic_service.dart';
import '../../models/manga_detail.dart';

class MangaDetailGenres extends StatefulWidget {
  final MangaDetail manga;
  final int initialVisibleCount;

  const MangaDetailGenres({
    super.key,
    required this.manga,
    this.initialVisibleCount = 9,
  });

  @override
  State<MangaDetailGenres> createState() => _MangaDetailGenresState();
}

class _MangaDetailGenresState extends State<MangaDetailGenres> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProviderChips(),
        _buildGenreTags(context),
      ],
    );
  }

  Widget _buildProviderChips() {
    final hasMal = widget.manga.malId > 0;
    final hasAnilist =
        widget.manga.anilistId != null && widget.manga.anilistId! > 0;
    final hasMangaUpdates =
        widget.manga.mangaUpdateId != null && widget.manga.mangaUpdateId! > 0;

    if (!hasMal && !hasAnilist && !hasMangaUpdates) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (hasMal)
            _buildExternalLinkChip(
              label: 'MAL',
              icon: Icons.link_rounded,
              color: const Color(0xFF2E51A2),
              url: 'https://myanimelist.net/manga/${widget.manga.malId}',
            ),
          if (hasAnilist)
            _buildExternalLinkChip(
              label: 'AniList',
              icon: Icons.tv_rounded,
              color: const Color(0xFF02A9FF),
              url: 'https://anilist.co/manga/${widget.manga.anilistId}',
            ),
          if (hasMangaUpdates)
            _buildExternalLinkChip(
              label: 'MangaUpdates',
              icon: Icons.menu_book_rounded,
              color: const Color(0xFF8C52FF),
              url:
                  'https://www.mangaupdates.com/series.html?id=${widget.manga.mangaUpdateId}',
            ),
        ],
      ),
    );
  }

  Widget _buildExternalLinkChip({
    required String label,
    required IconData icon,
    required Color color,
    required String url,
  }) {
    return InkWell(
      onTap: () => launchUrlString(url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.open_in_new_rounded, size: 11, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreTags(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> allChips = [];

    // 1. Genres (Primary color badges)
    if (widget.manga.genres != null) {
      for (final genre in widget.manga.genres!) {
        allChips.add(
          _buildTag(
            genre,
            colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
            colorScheme.primary,
            isDark: isDark,
          ),
        );
      }
    }

    // 2. Categories / Themes (Teal accent badges)
    if (widget.manga.categories != null) {
      for (final category in widget.manga.categories!) {
        allChips.add(
          _buildTag(
            category,
            Colors.tealAccent.withValues(alpha: isDark ? 0.18 : 0.14),
            isDark ? Colors.tealAccent[400] ?? Colors.teal : Colors.teal.shade700,
            isDark: isDark,
          ),
        );
      }
    }

    if (allChips.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalCount = allChips.length;
    final hasOverflow = totalCount > widget.initialVisibleCount;

    final visibleChips = (_isExpanded || !hasOverflow)
        ? allChips
        : allChips.take(widget.initialVisibleCount).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...visibleChips,
          if (hasOverflow)
            InkWell(
              onTap: () {
                AppHaptics.lightImpact();
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.45),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Show less'
                          : '+${totalCount - widget.initialVisibleCount} more',
                      style: GoogleFonts.inter(
                        color: colorScheme.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTag(
    String label,
    Color bgColor,
    Color textColor, {
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
