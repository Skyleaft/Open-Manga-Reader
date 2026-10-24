import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../history/models/progression.dart';
import '../../../history/services/progression_service.dart';
import 'stats_bottom_sheet_helpers.dart';

class ChaptersReadBottomSheet extends StatefulWidget {
  final List<MangaProgression> initialProgressions;
  final Map<String, Map<String, dynamic>> mangaDetailsMap;
  final void Function(String mangaId) onNavigateToDetail;

  const ChaptersReadBottomSheet({
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
      builder: (context) => ChaptersReadBottomSheet(
        initialProgressions: progressions,
        mangaDetailsMap: mangaDetailsMap,
        onNavigateToDetail: onNavigateToDetail,
      ),
    );
  }

  @override
  State<ChaptersReadBottomSheet> createState() =>
      _ChaptersReadBottomSheetState();
}

class _ChaptersReadBottomSheetState extends State<ChaptersReadBottomSheet> {
  final _progressionService = getIt<ProgressionService>();
  final _apiService = getIt<MangaApiService>();

  late List<MangaProgression> _progressions;
  String _viewMode = 'timeline';

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

    final completedLogs = <Map<String, dynamic>>[];
    for (final p in _progressions) {
      final mangaInfo = widget.mangaDetailsMap[p.mangaId];
      final mangaTitle =
          mangaInfo?['title'] ?? p.manga?.title ?? 'Manga #${p.mangaId}';
      final localImg = mangaInfo?['localImageUrl'] ?? p.manga?.localImageUrl;
      final remoteImg = mangaInfo?['imageUrl'] ?? p.manga?.imageUrl;

      for (final log in p.chapterLogs) {
        if (log.isCompleted) {
          completedLogs.add({
            'mangaId': p.mangaId,
            'mangaTitle': mangaTitle,
            'localImageUrl': localImg,
            'imageUrl': remoteImg,
            'chapterNumber': log.chapterNumber,
            'lastReadAt': log.lastReadAt,
            'readingTimeSeconds': log.readingTimeSeconds,
          });
        }
      }
    }

    completedLogs.sort(
      (a, b) =>
          (b['lastReadAt'] as DateTime).compareTo(a['lastReadAt'] as DateTime),
    );

    final groupedMap = <String, List<Map<String, dynamic>>>{};
    for (final item in completedLogs) {
      final mangaId = item['mangaId'] as String;
      groupedMap.putIfAbsent(mangaId, () => []).add(item);
    }

    final groupedList = groupedMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

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
            title: 'Chapters Completed',
            subtitle: '${completedLogs.length} total chapters read',
            icon: Icons.checklist_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                StatsSheetHelpers.buildFilterChip(
                  label: 'Timeline (${completedLogs.length})',
                  isSelected: _viewMode == 'timeline',
                  onTap: () => setState(() => _viewMode = 'timeline'),
                  isDark: isDark,
                  primary: primary,
                ),
                const SizedBox(width: 8),
                StatsSheetHelpers.buildFilterChip(
                  label: 'By Manga (${groupedList.length})',
                  isSelected: _viewMode == 'grouped',
                  onTap: () => setState(() => _viewMode = 'grouped'),
                  isDark: isDark,
                  primary: primary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: completedLogs.isEmpty
                ? StatsSheetHelpers.buildEmptyState(
                    isDark: isDark,
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No chapters completed',
                    description:
                        'Finish reading chapters to see your completion history.',
                  )
                : (_viewMode == 'timeline'
                    ? ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: completedLogs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = completedLogs[index];
                          final date = item['lastReadAt'] as DateTime;
                          final mangaId = item['mangaId'] as String;
                          final imageUrl = _apiService.getLocalImageUrl(
                            item['localImageUrl'],
                            item['imageUrl'],
                          );
                          final readSeconds =
                              item['readingTimeSeconds'] as int;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onNavigateToDetail(mangaId);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 44,
                                      height: 60,
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 120,
                                              placeholder: (_, _) => Container(
                                                color: isDark
                                                    ? Colors.grey[850]
                                                    : Colors.grey[200],
                                              ),
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                color: isDark
                                                    ? Colors.grey[850]
                                                    : Colors.grey[200],
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    size: 16),
                                              ),
                                            )
                                          : Container(
                                              color: isDark
                                                  ? Colors.grey[850]
                                                  : Colors.grey[200],
                                              child: const Icon(
                                                  Icons.menu_book,
                                                  size: 16),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['mangaTitle']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textLight,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981)
                                                    .withValues(
                                                        alpha:
                                                            isDark ? 0.2 : 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.check,
                                                      size: 12,
                                                      color: Color(0xFF10B981)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Ch. ${item['chapterNumber']}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (readSeconds > 0) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '• ${_formatReadingTime(readSeconds)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? Colors.white54
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    timeAgo(date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        itemCount: groupedList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = groupedList[index];
                          final mangaId = entry.key;
                          final logs = entry.value;
                          final firstItem = logs.first;
                          final mangaTitle =
                              firstItem['mangaTitle'] as String;
                          final imageUrl = _apiService.getLocalImageUrl(
                            firstItem['localImageUrl'],
                            firstItem['imageUrl'],
                          );

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onNavigateToDetail(mangaId);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 44,
                                      height: 60,
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 120,
                                              placeholder: (_, _) => Container(
                                                color: isDark
                                                    ? Colors.grey[850]
                                                    : Colors.grey[200],
                                              ),
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                color: isDark
                                                    ? Colors.grey[850]
                                                    : Colors.grey[200],
                                                child: const Icon(
                                                    Icons.broken_image,
                                                    size: 16),
                                              ),
                                            )
                                          : Container(
                                              color: isDark
                                                  ? Colors.grey[850]
                                                  : Colors.grey[200],
                                              child: const Icon(
                                                  Icons.menu_book,
                                                  size: 16),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mangaTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textLight,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${logs.length} chapter${logs.length > 1 ? 's' : ''} completed',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
