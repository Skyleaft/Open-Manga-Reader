import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../history/models/progression.dart';
import '../../../history/services/progression_service.dart';
import 'stats_bottom_sheet_helpers.dart';

class TimeSpentBottomSheet extends StatefulWidget {
  final List<MangaProgression> initialProgressions;
  final Map<String, Map<String, dynamic>> mangaDetailsMap;
  final void Function(String mangaId) onNavigateToDetail;

  const TimeSpentBottomSheet({
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
      builder: (context) => TimeSpentBottomSheet(
        initialProgressions: progressions,
        mangaDetailsMap: mangaDetailsMap,
        onNavigateToDetail: onNavigateToDetail,
      ),
    );
  }

  @override
  State<TimeSpentBottomSheet> createState() => _TimeSpentBottomSheetState();
}

class _TimeSpentBottomSheetState extends State<TimeSpentBottomSheet> {
  final _progressionService = getIt<ProgressionService>();
  final _apiService = getIt<MangaApiService>();

  late List<MangaProgression> _progressions;

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

    final sortedList = List<MangaProgression>.from(_progressions)
      ..sort((a, b) => b.totalReadingTime.compareTo(a.totalReadingTime));

    int totalSeconds = 0;
    int totalChapters = 0;
    for (final p in _progressions) {
      totalSeconds += p.totalReadingTime;
      for (final l in p.chapterLogs) {
        if (l.isCompleted) totalChapters++;
      }
    }

    final avgPerManga =
        _progressions.isNotEmpty ? (totalSeconds / _progressions.length).round() : 0;
    final avgPerChapter =
        totalChapters > 0 ? (totalSeconds / totalChapters).round() : 0;

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
            title: 'Time Spent Reading',
            subtitle: 'Analytics and duration breakdown',
            icon: Icons.access_time_filled_rounded,
            iconColor: const Color(0xFFF59E0B),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Hero Total Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL READING DURATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatReadingTime(totalSeconds),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _formatReadingTime(avgPerManga),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Avg / Title',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _formatReadingTime(avgPerChapter),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Avg / Chapter',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'BREAKDOWN BY TITLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                if (sortedList.isEmpty)
                  StatsSheetHelpers.buildEmptyState(
                    isDark: isDark,
                    icon: Icons.timer_outlined,
                    title: 'No time tracking yet',
                    description:
                        'Reading time will be tracked when reading chapters.',
                  )
                else
                  ...List.generate(sortedList.length, (index) {
                    final p = sortedList[index];
                    final mangaInfo = widget.mangaDetailsMap[p.mangaId];
                    final title = mangaInfo?['title'] ??
                        p.manga?.title ??
                        'Manga #${p.mangaId}';
                    final localImg =
                        mangaInfo?['localImageUrl'] ?? p.manga?.localImageUrl;
                    final remoteImg =
                        mangaInfo?['imageUrl'] ?? p.manga?.imageUrl;
                    final imageUrl =
                        _apiService.getLocalImageUrl(localImg, remoteImg);
                    final fraction = totalSeconds > 0
                        ? (p.totalReadingTime / totalSeconds).clamp(0.0, 1.0)
                        : 0.0;
                    final percentage = (fraction * 100).toStringAsFixed(1);

                    Color rankColor;
                    if (index == 0) {
                      rankColor = const Color(0xFFF59E0B);
                    } else if (index == 1) {
                      rankColor = const Color(0xFF94A3B8);
                    } else if (index == 2) {
                      rankColor = const Color(0xFFD97706);
                    } else {
                      rankColor =
                          isDark ? Colors.white38 : Colors.grey.shade400;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNavigateToDetail(p.mangaId);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: rankColor.withValues(
                                          alpha: isDark ? 0.2 : 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '#${index + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: rankColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 38,
                                      height: 52,
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
                                        const SizedBox(height: 4),
                                        Text(
                                          '$percentage% of total reading time',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatReadingTime(p.totalReadingTime),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 5,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    index == 0
                                        ? const Color(0xFFF59E0B)
                                        : primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
