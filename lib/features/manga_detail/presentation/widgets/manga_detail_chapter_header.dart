import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/manga_detail_controller.dart';

class MangaDetailChapterHeader extends StatefulWidget {
  final bool isAscending;
  final ChapterFilterOption currentFilter;
  final ValueChanged<ChapterFilterOption> onFilterChanged;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onScrapChapters;
  final VoidCallback? onDownloadChapters;

  const MangaDetailChapterHeader({
    super.key,
    required this.isAscending,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onToggleSort,
    required this.onSearchChanged,
    required this.onScrapChapters,
    this.onDownloadChapters,
  });

  @override
  State<MangaDetailChapterHeader> createState() =>
      _MangaDetailChapterHeaderState();
}

class _MangaDetailChapterHeaderState extends State<MangaDetailChapterHeader> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getFilterLabel(ChapterFilterOption option) {
    switch (option) {
      case ChapterFilterOption.all:
        return 'All';
      case ChapterFilterOption.unreadOnly:
        return 'Unread';
      case ChapterFilterOption.readOnly:
        return 'Read';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_isSearching) {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B)
              : colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Search chapter number or title...',
                  hintStyle: GoogleFonts.inter(
                    color: (isDark ? Colors.white60 : Colors.black45),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  widget.onSearchChanged(value.trim());
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                widget.onSearchChanged('');
              },
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Search Chapters',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isSearching = true);
                  },
                  icon: Icon(
                    Icons.search_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Scrape Chapters Online',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onScrapChapters();
                  },
                  icon: Icon(
                    Icons.cloud_download_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                if (widget.onDownloadChapters != null)
                  IconButton(
                    tooltip: 'Download Chapters',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onDownloadChapters!();
                    },
                    icon: Icon(
                      Icons.download_for_offline_outlined,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                PopupMenuButton<ChapterFilterOption>(
                  tooltip: 'Filter chapters',
                  initialValue: widget.currentFilter,
                  onSelected: (option) {
                    HapticFeedback.selectionClick();
                    widget.onFilterChanged(option);
                  },
                  icon: Icon(
                    widget.currentFilter == ChapterFilterOption.all
                        ? Icons.filter_list_rounded
                        : Icons.filter_alt_rounded,
                    color: widget.currentFilter == ChapterFilterOption.all
                        ? colorScheme.primary
                        : Colors.amber,
                    size: 20,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ChapterFilterOption.all,
                      child: Text('All Chapters'),
                    ),
                    const PopupMenuItem(
                      value: ChapterFilterOption.unreadOnly,
                      child: Text('Unread Only'),
                    ),
                    const PopupMenuItem(
                      value: ChapterFilterOption.readOnly,
                      child: Text('Read Only'),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onToggleSort();
                  },
                  icon: Text(
                    widget.isAscending ? 'Oldest' : 'Latest',
                    style: GoogleFonts.inter(
                      color: colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  label: AnimatedRotation(
                    turns: widget.isAscending ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: colorScheme.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (widget.currentFilter != ChapterFilterOption.all)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filtered: ${_getFilterLabel(widget.currentFilter)}',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () =>
                            widget.onFilterChanged(ChapterFilterOption.all),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
