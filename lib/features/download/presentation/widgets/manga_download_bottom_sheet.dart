import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/alert_banner.dart';
import '../../../history/models/progression.dart';
import '../../../manga_detail/models/manga_detail.dart';
import '../../services/download_service.dart';

class MangaDownloadBottomSheet extends StatefulWidget {
  final MangaDetail manga;
  final List<Chapter> chapters;
  final MangaProgression? progression;

  const MangaDownloadBottomSheet({
    super.key,
    required this.manga,
    required this.chapters,
    this.progression,
  });

  static Future<void> show(
    BuildContext context, {
    required MangaDetail manga,
    required List<Chapter> chapters,
    MangaProgression? progression,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MangaDownloadBottomSheet(
        manga: manga,
        chapters: chapters,
        progression: progression,
      ),
    );
  }

  @override
  State<MangaDownloadBottomSheet> createState() =>
      _MangaDownloadBottomSheetState();
}

class _MangaDownloadBottomSheetState extends State<MangaDownloadBottomSheet> {
  bool _isCustomSelecting = false;
  final Set<String> _selectedChapterIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final downloadService = getIt<DownloadService>();

    // Calculate unread chapters
    final unreadChapters = widget.chapters.where((c) {
      if (downloadService.isChapterDownloaded(widget.manga.id, c.id)) {
        return false;
      }
      final log = widget.progression?.chapterLogs
          .where((l) => l.chapterId == c.id || l.chapterNumber == c.chapterNumber)
          .firstOrNull;
      return log == null || !log.isCompleted;
    }).toList();

    // Not downloaded chapters
    final notDownloadedChapters = widget.chapters.where((c) {
      return !downloadService.isChapterDownloaded(widget.manga.id, c.id);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131927) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCustomSelecting
                              ? 'Select Chapters'
                              : 'Download Chapters',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          widget.manga.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isCustomSelecting)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isCustomSelecting = false;
                          _selectedChapterIds.clear();
                        });
                      },
                      child: const Text('Back'),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            if (!_isCustomSelecting) ...[
              // Option 1: Download All
              _buildOptionTile(
                context,
                icon: Icons.download_for_offline_rounded,
                title: 'Download All Chapters',
                subtitle: notDownloadedChapters.isEmpty
                    ? 'All chapters are already downloaded'
                    : '${notDownloadedChapters.length} chapters available to download',
                enabled: notDownloadedChapters.isNotEmpty,
                isDark: isDark,
                onTap: () {
                  _startDownload(context, notDownloadedChapters);
                },
              ),

              // Option 2: Download Unread
              _buildOptionTile(
                context,
                icon: Icons.mark_email_unread_outlined,
                title: 'Download Unread Chapters',
                subtitle: unreadChapters.isEmpty
                    ? 'No unread chapters to download'
                    : '${unreadChapters.length} unread chapters',
                enabled: unreadChapters.isNotEmpty,
                isDark: isDark,
                onTap: () {
                  _startDownload(context, unreadChapters);
                },
              ),

              // Option 3: Select Chapters
              _buildOptionTile(
                context,
                icon: Icons.checklist_rounded,
                title: 'Select Specific Chapters',
                subtitle: 'Choose individual chapters to download',
                enabled: notDownloadedChapters.isNotEmpty,
                isDark: isDark,
                onTap: () {
                  setState(() {
                    _isCustomSelecting = true;
                  });
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Multi-select actions bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: Icon(
                        _selectedChapterIds.length == notDownloadedChapters.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _selectedChapterIds.length == notDownloadedChapters.length
                            ? 'Deselect All'
                            : 'Select All (${notDownloadedChapters.length})',
                      ),
                      onPressed: () {
                        setState(() {
                          if (_selectedChapterIds.length ==
                              notDownloadedChapters.length) {
                            _selectedChapterIds.clear();
                          } else {
                            _selectedChapterIds.addAll(
                              notDownloadedChapters.map((c) => c.id),
                            );
                          }
                        });
                      },
                    ),
                    Text(
                      '${_selectedChapterIds.length} selected',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Chapter selection list
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = widget.chapters[index];
                    final isDownloaded = downloadService.isChapterDownloaded(
                      widget.manga.id,
                      chapter.id,
                    );
                    final isSelected = _selectedChapterIds.contains(chapter.id);

                    return CheckboxListTile(
                      value: isDownloaded ? true : isSelected,
                      onChanged: isDownloaded
                          ? null
                          : (val) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (val == true) {
                                  _selectedChapterIds.add(chapter.id);
                                } else {
                                  _selectedChapterIds.remove(chapter.id);
                                }
                              });
                            },
                      title: Text(
                        chapter.title.isNotEmpty
                            ? chapter.title
                            : 'Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDownloaded
                              ? Colors.grey
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      subtitle: Text(
                        isDownloaded
                            ? 'Already downloaded'
                            : (chapter.pageCount > 0
                                ? '${chapter.pageCount} pages'
                                : 'Ready to download'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDownloaded
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      secondary: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.1),
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
                              color: isDownloaded
                                  ? const Color(0xFF10B981)
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Download Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _selectedChapterIds.isEmpty
                      ? null
                      : () {
                          final selected = widget.chapters
                              .where((c) => _selectedChapterIds.contains(c.id))
                              .toList();
                          _startDownload(context, selected);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'Download ${_selectedChapterIds.length} Chapters',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startDownload(BuildContext context, List<Chapter> chapters) {
    if (chapters.isEmpty) return;

    final downloadService = getIt<DownloadService>();
    downloadService.downloadChapters(widget.manga, chapters);

    Navigator.pop(context);
    AlertBanner.show(
      context,
      'Added ${chapters.length} chapter${chapters.length > 1 ? "s" : ""} to download queue',
      type: AlertBannerType.success,
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      enabled: enabled,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled
              ? AppColors.primary
              : (isDark ? Colors.white38 : Colors.black38),
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: enabled
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? Colors.white38 : Colors.black38),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}
