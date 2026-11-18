import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/chapter_scraping_progress.dart';

class MangaDetailScrapingProgressCard extends StatelessWidget {
  final ChapterScrapingProgress progress;
  final VoidCallback onDismiss;

  const MangaDetailScrapingProgressCard({
    super.key,
    required this.progress,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = progress.isCompleted;
    final isFailed = progress.isFailed;
    final isStarting = progress.isStarting;

    Color cardColor;
    Color accentColor;
    IconData statusIcon;
    String statusTitle;

    if (isCompleted) {
      cardColor = isDark
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.green.withValues(alpha: 0.1);
      accentColor = Colors.greenAccent[700] ?? Colors.green;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Scraping Completed';
    } else if (isFailed) {
      cardColor = isDark
          ? Colors.red.withValues(alpha: 0.15)
          : Colors.red.withValues(alpha: 0.1);
      accentColor = Colors.redAccent;
      statusIcon = Icons.error_outline_rounded;
      statusTitle = 'Scraping Failed';
    } else {
      cardColor = isDark
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.primary.withValues(alpha: 0.08);
      accentColor = AppColors.primary;
      statusIcon = Icons.cloud_sync_rounded;
      statusTitle = isStarting
          ? 'Queuing scraping task...'
          : 'Scraping Chapter ${progress.chapterNumber % 1 == 0 ? progress.chapterNumber.toInt() : progress.chapterNumber}';
    }

    final double? progressValue = (isStarting || progress.totalPages == 0)
        ? null
        : (progress.percent / 100.0).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildSubtitle(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted || isFailed)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                  onPressed: onDismiss,
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (!isCompleted && !isFailed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progress.totalPages > 0
                      ? '${progress.downloadedPages} of ${progress.totalPages} pages'
                      : 'Connecting to worker...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  '${progress.percent}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildSubtitle() {
    if (progress.isCompleted) {
      return 'All chapter pages have been downloaded and processed.';
    }
    if (progress.isFailed) {
      return 'Failed to download chapter pages. Please try again.';
    }
    if (progress.isStarting) {
      return 'Dispatched to scraping worker...';
    }
    return 'Converting and saving high-res WebP pages';
  }
}
