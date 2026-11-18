import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/formatters.dart';

class MangaDetailStatsRow extends StatelessWidget {
  final double? rating;
  final int chapterCount;
  final int totalView;

  const MangaDetailStatsRow({
    super.key,
    required this.rating,
    required this.chapterCount,
    required this.totalView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.85);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Rating Metric Card
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            value: rating != null && rating! > 0
                ? rating!.toStringAsFixed(1)
                : 'N/A',
            label: 'Rating',
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        // Chapters Metric Card
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.auto_stories_rounded,
            iconColor: theme.colorScheme.primary,
            value: chapterCount > 0 ? '$chapterCount' : '0',
            label: 'Chapters',
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        // Reads Metric Card
        Expanded(
          child: _buildMetricCard(
            context,
            icon: Icons.visibility_rounded,
            iconColor: const Color(0xFF06B6D4),
            value: formatViewCount(totalView),
            label: 'Reads',
            cardBg: cardBg,
            borderColor: borderColor,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? Colors.white60 : Colors.black45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
