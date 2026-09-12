import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../routes/app_pages.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../reader/models/reader_content.dart';
import '../../settings/services/storage_service.dart';
import '../models/downloaded_chapter.dart';
import '../services/download_service.dart';

class DownloadedChaptersScreen extends StatefulWidget {
  const DownloadedChaptersScreen({super.key});

  @override
  State<DownloadedChaptersScreen> createState() =>
      _DownloadedChaptersScreenState();
}

class _DownloadedChaptersScreenState extends State<DownloadedChaptersScreen> {
  late final DownloadService _downloadService;
  List<DownloadedMangaGroup> _groups = [];
  int _totalBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _downloadService = getIt<DownloadService>();
    _loadDownloads();
  }

  void _loadDownloads() {
    final groups = _downloadService.getDownloadsGroupedByManga();
    final total = _downloadService.getTotalDownloadedBytes();
    setState(() {
      _groups = groups;
      _totalBytes = total;
      _isLoading = false;
    });
  }

  int get _totalChapters =>
      _groups.fold(0, (sum, g) => sum + g.chapterCount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Downloaded Chapters',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (_groups.isNotEmpty)
            IconButton(
              tooltip: 'Delete All Downloads',
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () => _confirmDeleteAll(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? _buildEmptyState(context, isDark)
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Top Storage Summary Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _buildSummaryCard(context, isDark),
                      ),
                    ),

                    // Manga Groups List
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final group = _groups[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMangaGroupCard(
                                context,
                                group,
                                isDark,
                              ),
                            );
                          },
                          childCount: _groups.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  colorScheme.primary.withValues(alpha: 0.25),
                  const Color(0xFF1E293B),
                ]
              : [
                  colorScheme.primary.withValues(alpha: 0.12),
                  colorScheme.primary.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.offline_pin_rounded,
                  color: colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Storage Used',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      StorageService.formatBytes(_totalBytes),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Downloaded Titles', '${_groups.length}', isDark),
              Container(
                width: 1,
                height: 24,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              _buildStatItem('Total Chapters', '$_totalChapters', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildMangaGroupCard(
    BuildContext context,
    DownloadedMangaGroup group,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final apiService = getIt<MangaApiService>();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: group.mangaCoverUrl != null &&
                    group.mangaCoverUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: apiService.getLocalImageUrl(
                      group.mangaCoverUrl!,
                      null,
                    ),
                    width: 44,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 44,
                      height: 60,
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Icon(Icons.book_outlined, size: 20),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 60,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Icon(Icons.book_outlined, size: 20),
                  ),
          ),
          title: Text(
            group.mangaTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${group.chapterCount} chapter${group.chapterCount > 1 ? "s" : ""} • ${group.formattedTotalSize}',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Delete all chapters of ${group.mangaTitle}',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                onPressed: () => _confirmDeleteManga(context, group),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
          children: group.chapters.map((chapter) {
            return _buildChapterRow(context, group, chapter, isDark);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChapterRow(
    BuildContext context,
    DownloadedMangaGroup group,
    DownloadedChapter chapter,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.6)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // Chapter number badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                chapter.chapterNumber % 1 == 0
                    ? chapter.chapterNumber.toInt().toString()
                    : chapter.chapterNumber.toString(),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Chapter details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.chapterTitle.isNotEmpty
                      ? chapter.chapterTitle
                      : 'Chapter ${chapter.chapterNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${chapter.pageCount} pages • ${chapter.formattedSize} • ${DateFormat("MMM dd, yyyy").format(chapter.downloadedAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Read Offline Button
          IconButton(
            tooltip: 'Read Offline',
            icon: Icon(
              Icons.chrome_reader_mode_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            onPressed: () => _openReaderOffline(context, group, chapter),
          ),

          // Delete Button
          IconButton(
            tooltip: 'Delete Chapter',
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            onPressed: () async {
              await _downloadService.deleteDownloadedChapter(
                group.mangaId,
                chapter.chapterId,
              );
              _loadDownloads();
            },
          ),
        ],
      ),
    );
  }

  void _openReaderOffline(
    BuildContext context,
    DownloadedMangaGroup group,
    DownloadedChapter chapter,
  ) {
    final allChapters = group.chapters.map((c) {
      return Chapter(
        id: c.chapterId,
        title: c.chapterTitle,
        chapterNumber: c.chapterNumber,
        date: c.downloadedAt,
        isChapterAvailable: true,
        pages: c.toChapterPages(),
      );
    }).toList();

    final content = ReaderContent(
      mangaId: group.mangaId,
      mangaTitle: group.mangaTitle,
      currentChapterNumber: chapter.chapterNumber,
      chapterId: chapter.chapterId,
      allChapters: allChapters,
      chapterTitle: chapter.chapterTitle,
      pages: chapter.toChapterPages(),
    );

    Navigator.pushNamed(context, AppRoutes.reader, arguments: content);
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.download_done_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Downloaded Chapters',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Download individual or full manga chapters from any manga detail screen to enjoy reading anywhere without an internet connection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteManga(
    BuildContext context,
    DownloadedMangaGroup group,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Manga Downloads'),
        content: Text(
          'Delete all ${group.chapterCount} downloaded chapters of "${group.mangaTitle}"? This will free up ${group.formattedTotalSize}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadService.deleteMangaDownloads(group.mangaId);
              _loadDownloads();
              if (context.mounted) {
                AlertBanner.show(
                  context,
                  'Deleted all downloads for "${group.mangaTitle}"',
                  type: AlertBannerType.info,
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Downloads'),
        content: Text(
          'Delete all $_totalChapters downloaded chapters across ${_groups.length} titles? This will free up ${StorageService.formatBytes(_totalBytes)} of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _downloadService.deleteAllDownloads();
              _loadDownloads();
              if (context.mounted) {
                AlertBanner.show(
                  context,
                  'All offline downloads deleted.',
                  type: AlertBannerType.info,
                );
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
