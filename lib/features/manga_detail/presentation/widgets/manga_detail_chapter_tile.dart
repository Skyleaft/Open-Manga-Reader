import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/formatters.dart';
import '../../../download/models/downloaded_chapter.dart';
import '../../../download/services/download_service.dart';
import '../../../history/models/progression.dart';
import '../../models/manga_detail.dart';

class MangaDetailChapterTile extends StatelessWidget {
  final MangaDetail? manga;
  final Chapter chapter;
  final bool isDark;
  final UserChapterLog? log;
  final VoidCallback? onTap;

  const MangaDetailChapterTile({
    super.key,
    this.manga,
    required this.chapter,
    required this.isDark,
    this.log,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isAvailable = chapter.isChapterAvailable;

    final bool isCompleted = log?.isCompleted ?? false;
    final bool isCurrentlyReading =
        log != null && !isCompleted && log!.lastReadPage > 0;

    final Color chapterBgColor = isCurrentlyReading
        ? colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08)
        : (isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.85));

    final Color borderColor = isCurrentlyReading
        ? colorScheme.primary.withValues(alpha: 0.4)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));

    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return InkWell(
      onTap: isAvailable
          ? () {
              HapticFeedback.selectionClick();
              onTap?.call();
            }
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: chapterBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Chapter number box
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isCurrentlyReading
                          ? colorScheme.primary
                              .withValues(alpha: isDark ? 0.3 : 0.15)
                          : (isDark
                              ? const Color(0xFF0F172A)
                              : colorScheme.primary
                                  .withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentlyReading
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : (isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05)),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        chapter.chapterNumber % 1 == 0
                            ? chapter.chapterNumber.toInt().toString()
                            : chapter.chapterNumber.toString(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isCurrentlyReading
                              ? colorScheme.primary
                              : textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chapter info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title.isNotEmpty
                              ? chapter.title
                              : 'Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: isCurrentlyReading
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontSize: 14.5,
                            color: isCurrentlyReading
                                ? colorScheme.primary
                                : textColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Language Badge
                            if (chapter.language.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  chapter.language.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),

                            // Provider Badge
                            if (chapter.chapterProvider != null &&
                                chapter.chapterProvider!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (chapter.chapterProviderIcon != null) ...[
                                      Container(
                                        width: 12,
                                        height: 12,
                                        margin: const EdgeInsets.only(right: 4),
                                        child: CachedNetworkImage(
                                          imageUrl: chapter
                                              .chapterProviderIcon!,
                                          width: 12,
                                          height: 12,
                                          memCacheWidth: 40,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.link_rounded,
                                            size: 10,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                    Text(
                                      chapter.chapterProvider!,
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // View Count
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  color:
                                      isDark ? Colors.white54 : Colors.black45,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  formatViewCount(chapter.totalView),
                                  style: GoogleFonts.inter(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                            // Page Count
                            if (chapter.pageCount > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_stories_outlined,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${chapter.pageCount} pgs',
                                    style: GoogleFonts.inter(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Date row
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM dd, yyyy').format(chapter.date),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '·',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo(chapter.date),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Completion Badge & Chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDownloadButton(context, isDark, isAvailable),
                      _buildCompletionBadge(
                          context, isCompleted, isCurrentlyReading, log),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white38 : Colors.black38,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
              if (isCurrentlyReading) ...[
                const SizedBox(height: 8),
                _buildProgressionBar(context, log),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionBadge(
    BuildContext context,
    bool isCompleted,
    bool isCurrentlyReading,
    UserChapterLog? log,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981)
              .withValues(alpha: isDark ? 0.2 : 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color:
                  isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              size: 13,
            ),
            const SizedBox(width: 3),
            Text(
              'READ',
              style: GoogleFonts.inter(
                color:
                    isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    if (isCurrentlyReading && log != null && log.lastReadPage > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary
              .withValues(alpha: isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Text(
          'PG. ${log.lastReadPage}',
          style: GoogleFonts.inter(
            color: theme.colorScheme.primary,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProgressionBar(BuildContext context, UserChapterLog? log) {
    if (log == null || log.isCompleted || log.totalPages <= 0) {
      return const SizedBox.shrink();
    }

    final double progressPercentage =
        (log.lastReadPage / log.totalPages).clamp(0.0, 1.0);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercentage,
            backgroundColor: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.06),
            valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Page ${log.lastReadPage} of ${log.totalPages} (${(progressPercentage * 100).toInt()}%)',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    bool isDark,
    bool isAvailable,
  ) {
    if (manga == null || !getIt.isRegistered<DownloadService>()) {
      return const SizedBox.shrink();
    }

    final downloadService = getIt<DownloadService>();

    return ValueListenableBuilder<Map<String, DownloadTask>>(
      valueListenable: downloadService.tasksNotifier,
      builder: (context, tasks, _) {
        final task = tasks[chapter.id];
        final isDownloaded =
            downloadService.isChapterDownloaded(manga!.id, chapter.id);

        if (task != null && task.isDownloading) {
          final progress = task.progress;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip:
                    'Downloading ${(progress * 100).toInt()}% (Tap to cancel)',
                onPressed: () =>
                    _confirmCancelDownload(context, downloadService),
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Icon(Icons.close_rounded, size: 10),
                  ],
                ),
              ),
            ),
          );
        }

        if (task != null && task.isQueued) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Queued (Tap to cancel)',
                onPressed: () =>
                    _confirmCancelDownload(context, downloadService),
                icon: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
            ),
          );
        }

        if (isDownloaded) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 30,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Downloaded (Tap for options)',
                onPressed: () =>
                    _showDownloadedOptions(context, downloadService),
                icon: const Icon(
                  Icons.offline_pin_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Download chapter',
              onPressed: isAvailable
                  ? () {
                      HapticFeedback.selectionClick();
                      downloadService.downloadChapter(manga!, chapter);
                    }
                  : null,
              icon: Icon(
                Icons.download_for_offline_outlined,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmCancelDownload(
    BuildContext context,
    DownloadService downloadService,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text(
          'Cancel downloading Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              downloadService.cancelDownload(chapter.id);
              Navigator.pop(ctx);
            },
            child: const Text('Cancel Download'),
          ),
        ],
      ),
    );
  }

  void _showDownloadedOptions(
    BuildContext context,
    DownloadService downloadService,
  ) {
    final downloaded =
        downloadService.getDownloadedChapter(manga!.id, chapter.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.offline_pin_rounded,
                    color: Color(0xFF10B981),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chapter.title.isNotEmpty
                          ? chapter.title
                          : 'Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (downloaded != null)
                Text(
                  'Downloaded ${downloaded.pageCount} pages (${downloaded.formattedSize}) on ${DateFormat("MMM dd, yyyy").format(downloaded.downloadedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onTap?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.chrome_reader_mode_rounded),
                label: const Text('Read Offline Now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  await downloadService.deleteDownloadedChapter(
                    manga!.id,
                    chapter.id,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete Download'),
              ),
            ],
          ),
        );
      },
    );
  }
}
