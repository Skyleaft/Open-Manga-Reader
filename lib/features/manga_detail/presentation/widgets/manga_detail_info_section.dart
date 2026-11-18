import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/manga_detail.dart';

class MangaDetailInfoSection extends StatelessWidget {
  final MangaDetail manga;
  final bool isDark;

  const MangaDetailInfoSection({
    super.key,
    required this.manga,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typeStr = manga.type.isNotEmpty ? manga.type.toUpperCase() : 'MANGA';
    final statusStr = manga.status?.toUpperCase() ?? 'ONGOING';

    final isCompleted = statusStr.contains('COMPLETE');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status & Type badges
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Text(
                typeStr,
                style: GoogleFonts.inter(
                  color: colorScheme.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isCompleted ? const Color(0xFF10B981) : Colors.amber)
                      .withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                statusStr,
                style: GoogleFonts.inter(
                  color: isCompleted
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                      : (isDark ? Colors.amberAccent : Colors.amber.shade800),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Title
        Text(
          manga.title,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        // Author
        if (manga.author.isNotEmpty)
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  manga.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
