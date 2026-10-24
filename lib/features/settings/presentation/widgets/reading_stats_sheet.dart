import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../history/models/progression.dart';
import '../../../history/services/progression_service.dart';
import 'stats_bottom_sheet_helpers.dart';

class ReadingStatsBottomSheet extends StatefulWidget {
  final List<MangaProgression> initialProgressions;
  final Map<String, Map<String, dynamic>> mangaDetailsMap;
  final void Function(String mangaId) onNavigateToDetail;

  const ReadingStatsBottomSheet({
    super.key,
    required this.initialProgressions,
    required this.mangaDetailsMap,
    required this.onNavigateToDetail,
  });

  static void show(
    BuildContext context, {
    required List<MangaProgression> progressions,
    required Map<String, Map<String, dynamic>> mangaDetailsMap,
    required void Function(String mangaId) onNavigateToDetail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReadingStatsBottomSheet(
        initialProgressions: progressions,
        mangaDetailsMap: mangaDetailsMap,
        onNavigateToDetail: onNavigateToDetail,
      ),
    );
  }

  @override
  State<ReadingStatsBottomSheet> createState() =>
      _ReadingStatsBottomSheetState();
}

class _ReadingStatsBottomSheetState extends State<ReadingStatsBottomSheet> {
  final _progressionService = getIt<ProgressionService>();
  final _apiService = getIt<MangaApiService>();

  late List<MangaProgression> _progressions;
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    _progressions = List.from(widget.initialProgressions);
    _progressionService.addListener(_onProgressionChanged);
  }

  @override
  void dispose() {
    _progressionService.removeListener(_onProgressionChanged);
    super.dispose();
  }

  void _onProgressionChanged() async {
    final updated = await _progressionService.getAllProgressions();
    if (mounted) {
      setState(() {
        _progressions = updated;
      });
    }
  }

  String _formatReadingTime(int seconds) {
    if (seconds <= 0) return '0m';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final sortedList = List<MangaProgression>.from(_progressions);
    if (_sortBy == 'recent') {
      sortedList.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    } else if (_sortBy == 'time') {
      sortedList
          .sort((a, b) => b.totalReadingTime.compareTo(a.totalReadingTime));
    } else if (_sortBy == 'chapters') {
      sortedList.sort((a, b) {
        final aCount = a.chapterLogs.where((l) => l.isCompleted).length;
        final bCount = b.chapterLogs.where((l) => l.isCompleted).length;
        return bCount.compareTo(aCount);
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          StatsSheetHelpers.buildHandle(isDark),
          StatsSheetHelpers.buildHeader(
            context,
            title: 'Reading Statistics',
            subtitle: '${_progressions.length} titles tracked',
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF3B82F6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Sort by:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                StatsSheetHelpers.buildFilterChip(
                  label: 'Recent',
                  isSelected: _sortBy == 'recent',
                  onTap: () => setState(() => _sortBy = 'recent'),
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 6),
                StatsSheetHelpers.buildFilterChip(
                  label: 'Most Time',
                  isSelected: _sortBy == 'time',
                  onTap: () => setState(() => _sortBy = 'time'),
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 6),
                StatsSheetHelpers.buildFilterChip(
                  label: 'Chapters',
                  isSelected: _sortBy == 'chapters',
                  onTap: () => setState(() => _sortBy = 'chapters'),
                  isDark: isDark,
                  primary: primary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sortedList.isEmpty
                ? StatsSheetHelpers.buildEmptyState(
                    isDark: isDark,
                    icon: Icons.menu_book_rounded,
                    title: 'No reading activity yet',
                    description:
                        'Read any manga chapter to automatically record your statistics.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: sortedList.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = sortedList[index];
                      final mangaInfo = widget.mangaDetailsMap[p.mangaId];
                      final title = mangaInfo?['title'] ??
                          p.manga?.title ??
                          'Manga #${p.mangaId}';
                      final author = mangaInfo?['author'] ??
                          p.manga?.author ??
                          'Unknown Author';
                      final localImg = mangaInfo?['localImageUrl'] ??
                          p.manga?.localImageUrl;
                      final remoteImg =
                          mangaInfo?['imageUrl'] ?? p.manga?.imageUrl;
                      final imageUrl =
                          _apiService.getLocalImageUrl(localImg, remoteImg);
                      final completedCount =
                          p.chapterLogs.where((l) => l.isCompleted).length;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigateToDetail(p.mangaId);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  width: 52,
                                  height: 72,
                                  child: imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 150,
                                          placeholder: (_, _) => Container(
                                            color: isDark
                                                ? Colors.grey[850]
                                                : Colors.grey[200],
                                          ),
                                          errorBuilder: (_, _, _) => Container(
                                            color: isDark
                                                ? Colors.grey[850]
                                                : Colors.grey[200],
                                            child: const Icon(
                                              Icons.broken_image,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: isDark
                                              ? Colors.grey[850]
                                              : Colors.grey[200],
                                          child: const Icon(
                                            Icons.menu_book,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      author,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        StatsSheetHelpers.buildStatBadge(
                                          icon: Icons.task_alt_rounded,
                                          label: '$completedCount ch',
                                          color: const Color(0xFF10B981),
                                          isDark: isDark,
                                        ),
                                        StatsSheetHelpers.buildStatBadge(
                                          icon: Icons.timer_outlined,
                                          label: _formatReadingTime(
                                              p.totalReadingTime),
                                          color: const Color(0xFFF59E0B),
                                          isDark: isDark,
                                        ),
                                        StatsSheetHelpers.buildStatBadge(
                                          icon: Icons.history_rounded,
                                          label: timeAgo(p.lastReadAt),
                                          color: const Color(0xFF64748B),
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark
                                    ? Colors.white30
                                    : Colors.grey.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
