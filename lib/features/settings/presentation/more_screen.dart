import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/services/auth_service.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../../routes/app_pages.dart';
import '../../download/services/download_service.dart';
import '../../library/models/library_manga.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import 'base_api_setting_screen.dart';
import 'storage_setting_screen.dart';
import 'theme_setting_screen.dart';
import 'widgets/app_update_dialog.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with AutomaticKeepAliveClientMixin {
  String _appVersion = 'Loading...';
  final _progressionService = getIt<ProgressionService>();
  final _apiService = getIt<MangaApiService>();
  final _storageService = getIt<StorageService>();

  @override
  bool get wantKeepAlive => true;

  List<MangaProgression> _progressions = [];
  Map<String, Map<String, dynamic>> _mangaDetailsMap = {};
  bool _isLoadingStats = true;
  int _totalChaptersRead = 0;
  int _totalReadingTimeSeconds = 0;
  int _cacheSizeBytes = 0;
  int _downloadedSizeBytes = 0;
  int _downloadedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadStats();
    _loadStorageSizes();
  }

  Future<void> _loadStorageSizes() async {
    final cacheSize = await _storageService.getCacheSizeBytes();
    int downloadSize = 0;
    int downloadCount = 0;
    try {
      final downloadService = getIt<DownloadService>();
      downloadSize = downloadService.getTotalDownloadedBytes();
      final groups = downloadService.getDownloadsGroupedByManga();
      downloadCount = groups.fold<int>(0, (sum, g) => sum + g.chapterCount);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _cacheSizeBytes = cacheSize;
        _downloadedSizeBytes = downloadSize;
        _downloadedCount = downloadCount;
      });
    }
  }

  Future<void> _loadCacheSize() => _loadStorageSizes();

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final progressions = await _progressionService.getAllProgressions();

      final detailService = getIt<MangaDetailService>();
      final libraryData = await _apiService.getUserLibrary();
      final libraryMap = <String, LibraryManga>{};
      for (final json in libraryData) {
        try {
          final manga = LibraryManga.fromMap(json);
          libraryMap[manga.id] = manga;
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> detailsMap = {};
      final missingMangaIds = <String>{};

      for (final p in progressions) {
        if (detailsMap.containsKey(p.mangaId)) continue;

        if (p.manga != null) {
          detailsMap[p.mangaId] = {
            'title': p.manga!.title,
            'author': p.manga!.author,
            'imageUrl': p.manga!.imageUrl ?? '',
            'localImageUrl': p.manga!.localImageUrl,
          };
        } else if (libraryMap.containsKey(p.mangaId)) {
          final libManga = libraryMap[p.mangaId]!;
          detailsMap[p.mangaId] = {
            'title': libManga.title,
            'author': libManga.author,
            'imageUrl': libManga.imageUrl,
            'localImageUrl': libManga.imageUrl,
          };
        } else {
          final cached = await detailService.getDetail(p.mangaId);
          if (cached != null) {
            detailsMap[p.mangaId] = {
              'title': cached.title,
              'author': cached.author,
              'imageUrl': cached.imageUrl ?? '',
              'localImageUrl': cached.localImageUrl,
            };
          } else {
            missingMangaIds.add(p.mangaId);
          }
        }
      }

      if (missingMangaIds.isNotEmpty) {
        await Future.wait(
          missingMangaIds.map((mangaId) async {
            try {
              final detailJson = await _apiService.getMangaDetail(mangaId);
              detailsMap[mangaId] = {
                'title': detailJson['title'] ?? 'Unknown Title',
                'author': detailJson['author'] ?? 'Unknown Author',
                'imageUrl': detailJson['imageUrl'] ?? '',
                'localImageUrl': detailJson['localImageUrl'],
              };
            } catch (_) {
              detailsMap[mangaId] = {
                'title': 'Manga ID: $mangaId',
                'author': 'Unknown Author',
                'imageUrl': '',
                'localImageUrl': null,
              };
            }
          }),
        );
      }

      int totalChapters = 0;
      int totalSeconds = 0;
      for (final p in progressions) {
        totalSeconds += p.totalReadingTime;
        for (final log in p.chapterLogs) {
          if (log.isCompleted) {
            totalChapters++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _progressions = progressions;
          _mangaDetailsMap = detailsMap;
          _totalChaptersRead = totalChapters;
          _totalReadingTimeSeconds = totalSeconds;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
        });
      }
    }
  }

  int _versionTapCount = 0;
  DateTime? _lastVersionTapTime;
  bool _isCheckingUpdate = false;

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTapTime == null ||
        now.difference(_lastVersionTapTime!) > const Duration(seconds: 2)) {
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }
    _lastVersionTapTime = now;

    HapticFeedback.selectionClick();

    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      _checkLatestVersionManual();
    } else if (_versionTapCount >= 2) {
      final remaining = 5 - _versionTapCount;
      AlertBanner.show(
        context,
        'Tap $remaining more time${remaining > 1 ? 's' : ''} to check for updates',
        type: AlertBannerType.info,
        duration: const Duration(milliseconds: 1000),
      );
    }
  }

  Future<void> _checkLatestVersionManual() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    AlertBanner.show(
      context,
      'Checking for latest version...',
      type: AlertBannerType.info,
      duration: const Duration(seconds: 2),
    );

    try {
      final updateService = UpdateService();
      final releaseInfo = await updateService.getLatestReleaseInfo();

      if (!mounted) return;

      if (releaseInfo == null) {
        AlertBanner.show(
          context,
          'Failed to check for updates. Check your connection.',
          type: AlertBannerType.error,
        );
      } else if (releaseInfo['hasUpdate'] == true) {
        _showUpdateDialog(releaseInfo);
      } else {
        AlertBanner.show(
          context,
          'You are already using the latest version ($_appVersion)',
          type: AlertBannerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Error checking update: $e',
          type: AlertBannerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showUpdateDialog(Map<String, dynamic> updateData) {
    AppUpdateDialog.show(context, updateData);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, authService.currentUser),
              _buildStatsCard(isDark),
              const SizedBox(height: 32),

              _buildCategoryTitle('Settings'),
              _buildMenuItem(
                context,
                icon: Icons.api_outlined,
                title: 'Base API Setting',
                onTap: () {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BaseApiSettingScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: '${themeProvider.themeModeName} • ${themeProvider.currentScheme.name}',
                onTap: () {
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ThemeSettingScreen(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notification',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.language_outlined,
                title: 'Language',
                onTap: () {},
              ),

              const SizedBox(height: 24),
              _buildCategoryTitle('Data'),
              _buildMenuItem(
                context,
                icon: Icons.download_done_rounded,
                title: 'Downloaded Chapters',
                subtitle: _downloadedCount > 0
                    ? '$_downloadedCount chapters (${StorageService.formatBytes(_downloadedSizeBytes)})'
                    : 'Manage offline chapters',
                onTap: _openDownloadedChapters,
              ),
              _buildMenuItem(
                context,
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Cache',
                subtitle: _cacheSizeBytes > 0
                    ? StorageService.formatBytes(_cacheSizeBytes)
                    : '0 B',
                onTap: _handleClearCache,
              ),
              _buildMenuItem(
                context,
                icon: Icons.data_usage_outlined,
                title: 'Storage Usage',
                subtitle: 'Detailed breakdown & cache management',
                onTap: () async {
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StorageSettingScreen(),
                    ),
                  );
                  if (mounted) {
                    _loadStorageSizes();
                  }
                },
              ),

              const SizedBox(height: 24),
              _buildCategoryTitle('Stats'),
              _buildMenuItem(
                context,
                icon: Icons.bar_chart_rounded,
                title: 'Reading Statistics',
                subtitle: _progressions.isNotEmpty
                    ? '${_progressions.length} titles tracked'
                    : 'Track titles and progress',
                onTap: _showReadingStatsDialog,
              ),
              _buildMenuItem(
                context,
                icon: Icons.access_time_filled_rounded,
                title: 'Time Spent',
                subtitle: _totalReadingTimeSeconds > 0
                    ? '${_formatReadingTime(_totalReadingTimeSeconds)} total duration'
                    : '0m',
                onTap: _showTimeSpentDialog,
              ),
              _buildMenuItem(
                context,
                icon: Icons.checklist_rounded,
                title: 'Chapters Read',
                subtitle: _totalChaptersRead > 0
                    ? '$_totalChaptersRead chapters completed'
                    : '0 chapters',
                onTap: _showChaptersReadDialog,
              ),

              const SizedBox(height: 24),
              _buildCategoryTitle('Support'),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.bug_report_outlined,
                title: 'Report Bug',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.library_add_outlined,
                title: 'Request Manga',
                onTap: () {},
              ),

              const SizedBox(height: 24),
              _buildCategoryTitle('About'),
              _buildMenuItem(
                context,
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: _appVersion,
                onTap: _handleVersionTap,
              ),
              _buildMenuItem(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.code,
                title: 'Open Source Licenses',
                onTap: () {},
              ),

              const SizedBox(height: 32),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    if (_isLoadingStats) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 36, height: 36, borderRadius: 10),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 130, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 80, height: 10, borderRadius: 4),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 72, borderRadius: 14)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 72, borderRadius: 14)),
                SizedBox(width: 10),
                Expanded(child: ShimmerBox(height: 72, borderRadius: 14)),
              ],
            ),
          ],
        ),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;

    MangaProgression? topManga;
    if (_progressions.isNotEmpty) {
      topManga = _progressions.reduce(
        (a, b) => a.totalReadingTime > b.totalReadingTime ? a : b,
      );
    }

    final topMangaInfo = topManga != null ? _mangaDetailsMap[topManga.mangaId] : null;
    final topMangaTitle = topMangaInfo?['title'] ?? topManga?.manga?.title;
    final hasTopManga = topManga != null && topManga.totalReadingTime > 0 && topMangaTitle != null;

    final avgMinutesPerChapter = (_totalChaptersRead > 0 && _totalReadingTimeSeconds > 0)
        ? (_totalReadingTimeSeconds / 60 / _totalChaptersRead).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : primary.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary,
                          primary.withValues(alpha: 0.75),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reading Analytics',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textLight,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _progressions.isNotEmpty
                              ? '${_progressions.length} titles tracked'
                              : 'Track your reading journey',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showReadingStatsDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 16, color: primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3 Metric Tiles
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      isDark: isDark,
                      icon: Icons.collections_bookmark_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      value: '${_progressions.length}',
                      label: 'Titles Read',
                      badge: _progressions.isNotEmpty ? 'Active' : null,
                      onTap: _showReadingStatsDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      isDark: isDark,
                      icon: Icons.timer_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      value: _formatReadingTime(_totalReadingTimeSeconds),
                      label: 'Time Spent',
                      badge: avgMinutesPerChapter > 0 ? '~$avgMinutesPerChapter m/ch' : null,
                      onTap: _showTimeSpentDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      isDark: isDark,
                      icon: Icons.task_alt_rounded,
                      iconColor: const Color(0xFF10B981),
                      value: '$_totalChaptersRead',
                      label: 'Chapters',
                      badge: _totalChaptersRead > 0 ? 'Completed' : null,
                      onTap: _showChaptersReadDialog,
                    ),
                  ),
                ],
              ),

              // Highlight Banner (Top Read Manga or encouragement)
              if (hasTopManga) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _navigateToDetail(topManga!.mangaId),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Top Title: ',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: topMangaTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textLight,
                                  ),
                                ),
                                TextSpan(
                                  text: ' (${_formatReadingTime(topManga.totalReadingTime)})',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (badge != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(String mangaId) async {
    HapticFeedback.selectionClick();
    try {
      final detailService = getIt<MangaDetailService>();
      MangaDetail? detail = await detailService.getDetail(mangaId);

      if (detail == null) {
        final matches = _progressions.where((p) => p.mangaId == mangaId);
        if (matches.isNotEmpty && matches.first.manga != null) {
          detail = MangaDetail.fromMangaSummary(matches.first.manga!);
        } else {
          final data = await _apiService.getMangaDetail(mangaId);
          detail = MangaDetail.fromMap(data);
          await detailService.saveDetail(detail);
        }
      }

      if (!mounted) return;
      await Navigator.pushNamed(context, AppRoutes.detail, arguments: detail);
      if (mounted) {
        _loadStats();
      }
    } catch (e) {
      debugPrint('Error navigating to manga detail: $e');
    }
  }

  void _showReadingStatsDialog() {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String sortBy = 'recent';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final sortedList = List<MangaProgression>.from(_progressions);
            if (sortBy == 'recent') {
              sortedList.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
            } else if (sortBy == 'time') {
              sortedList.sort((a, b) => b.totalReadingTime.compareTo(a.totalReadingTime));
            } else if (sortBy == 'chapters') {
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
                  _buildSheetHandle(isDark),
                  _buildSheetHeader(
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
                        _buildFilterChip(
                          label: 'Recent',
                          isSelected: sortBy == 'recent',
                          onTap: () => setModalState(() => sortBy = 'recent'),
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'Most Time',
                          isSelected: sortBy == 'time',
                          onTap: () => setModalState(() => sortBy = 'time'),
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          label: 'Chapters',
                          isSelected: sortBy == 'chapters',
                          onTap: () => setModalState(() => sortBy = 'chapters'),
                          isDark: isDark,
                          primary: primary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: sortedList.isEmpty
                        ? _buildEmptyStatsState(
                            isDark: isDark,
                            icon: Icons.menu_book_rounded,
                            title: 'No reading activity yet',
                            description: 'Read any manga chapter to automatically record your statistics.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            itemCount: sortedList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final p = sortedList[index];
                              final mangaInfo = _mangaDetailsMap[p.mangaId];
                              final title = mangaInfo?['title'] ?? p.manga?.title ?? 'Manga #${p.mangaId}';
                              final author = mangaInfo?['author'] ?? p.manga?.author ?? 'Unknown Author';
                              final localImg = mangaInfo?['localImageUrl'] ?? p.manga?.localImageUrl;
                              final remoteImg = mangaInfo?['imageUrl'] ?? p.manga?.imageUrl;
                              final imageUrl = _apiService.getLocalImageUrl(localImg, remoteImg);
                              final completedCount = p.chapterLogs.where((l) => l.isCompleted).length;

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _navigateToDetail(p.mangaId);
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
                                                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                  ),
                                                  errorBuilder: (_, _, _) => Container(
                                                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                    child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                                  ),
                                                )
                                              : Container(
                                                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                  child: const Icon(Icons.menu_book, size: 20, color: Colors.grey),
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
                                                color: isDark ? Colors.white : AppColors.textLight,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              author,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.white54 : Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                _buildStatBadge(
                                                  icon: Icons.task_alt_rounded,
                                                  label: '$completedCount ch',
                                                  color: const Color(0xFF10B981),
                                                  isDark: isDark,
                                                ),
                                                _buildStatBadge(
                                                  icon: Icons.timer_outlined,
                                                  label: _formatReadingTime(p.totalReadingTime),
                                                  color: const Color(0xFFF59E0B),
                                                  isDark: isDark,
                                                ),
                                                _buildStatBadge(
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
                                        color: isDark ? Colors.white30 : Colors.grey.shade400,
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
          },
        );
      },
    );
  }

  void _showTimeSpentDialog() {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final sortedList = List<MangaProgression>.from(_progressions)
      ..sort((a, b) => b.totalReadingTime.compareTo(a.totalReadingTime));

    final avgPerManga = _progressions.isNotEmpty
        ? (_totalReadingTimeSeconds / _progressions.length).round()
        : 0;
    final avgPerChapter = _totalChaptersRead > 0
        ? (_totalReadingTimeSeconds / _totalChaptersRead).round()
        : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
              _buildSheetHandle(isDark),
              _buildSheetHeader(
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
                          colors: [
                            primary,
                            AppColors.secondary,
                          ],
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
                            _formatReadingTime(_totalReadingTimeSeconds),
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
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                                        style: TextStyle(fontSize: 11, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                                        style: TextStyle(fontSize: 11, color: Colors.white70),
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
                      _buildEmptyStatsState(
                        isDark: isDark,
                        icon: Icons.timer_outlined,
                        title: 'No time tracking yet',
                        description: 'Reading time will be tracked when reading chapters.',
                      )
                    else
                      ...List.generate(sortedList.length, (index) {
                        final p = sortedList[index];
                        final mangaInfo = _mangaDetailsMap[p.mangaId];
                        final title = mangaInfo?['title'] ?? p.manga?.title ?? 'Manga #${p.mangaId}';
                        final localImg = mangaInfo?['localImageUrl'] ?? p.manga?.localImageUrl;
                        final remoteImg = mangaInfo?['imageUrl'] ?? p.manga?.imageUrl;
                        final imageUrl = _apiService.getLocalImageUrl(localImg, remoteImg);
                        final fraction = _totalReadingTimeSeconds > 0
                            ? (p.totalReadingTime / _totalReadingTimeSeconds).clamp(0.0, 1.0)
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
                          rankColor = isDark ? Colors.white38 : Colors.grey.shade400;
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
                              _navigateToDetail(p.mangaId);
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
                                          color: rankColor.withValues(alpha: isDark ? 0.2 : 0.12),
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
                                                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                  ),
                                                  errorBuilder: (_, _, _) => Container(
                                                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                    child: const Icon(Icons.broken_image, size: 16),
                                                  ),
                                                )
                                              : Container(
                                                  color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                  child: const Icon(Icons.menu_book, size: 16),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : AppColors.textLight,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$percentage% of total reading time',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white54 : Colors.grey.shade600,
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
                                          color: isDark ? Colors.white : AppColors.textLight,
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
                                        index == 0 ? const Color(0xFFF59E0B) : primary,
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
      },
    );
  }

  void _showChaptersReadDialog() {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final completedLogs = <Map<String, dynamic>>[];
    for (final p in _progressions) {
      final mangaInfo = _mangaDetailsMap[p.mangaId];
      final mangaTitle = mangaInfo?['title'] ?? p.manga?.title ?? 'Manga #${p.mangaId}';
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
      (a, b) => (b['lastReadAt'] as DateTime).compareTo(a['lastReadAt'] as DateTime),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String viewMode = 'timeline';

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  _buildSheetHandle(isDark),
                  _buildSheetHeader(
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
                        _buildFilterChip(
                          label: 'Timeline (${completedLogs.length})',
                          isSelected: viewMode == 'timeline',
                          onTap: () => setModalState(() => viewMode = 'timeline'),
                          isDark: isDark,
                          primary: primary,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'By Manga (${groupedList.length})',
                          isSelected: viewMode == 'grouped',
                          onTap: () => setModalState(() => viewMode = 'grouped'),
                          isDark: isDark,
                          primary: primary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: completedLogs.isEmpty
                        ? _buildEmptyStatsState(
                            isDark: isDark,
                            icon: Icons.check_circle_outline_rounded,
                            title: 'No chapters completed',
                            description: 'Finish reading chapters to see your completion history.',
                          )
                        : (viewMode == 'timeline'
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
                                  final readSeconds = item['readingTimeSeconds'] as int;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _navigateToDetail(mangaId);
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
                                                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                      ),
                                                      errorBuilder: (_, _, _) => Container(
                                                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                        child: const Icon(Icons.broken_image, size: 16),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                      child: const Icon(Icons.menu_book, size: 16),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${item['mangaTitle']}',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : AppColors.textLight,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
                                                          const SizedBox(width: 3),
                                                          Text(
                                                            'Ch. ${item['chapterNumber']}',
                                                            style: const TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w700,
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
                                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
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
                                              color: isDark ? Colors.white38 : Colors.grey.shade500,
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
                                  final mangaTitle = firstItem['mangaTitle'] as String;
                                  final imageUrl = _apiService.getLocalImageUrl(
                                    firstItem['localImageUrl'],
                                    firstItem['imageUrl'],
                                  );

                                  return InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _navigateToDetail(mangaId);
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
                                                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                      ),
                                                      errorBuilder: (_, _, _) => Container(
                                                        color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                        child: const Icon(Icons.broken_image, size: 16),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                                                      child: const Icon(Icons.menu_book, size: 16),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  mangaTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : AppColors.textLight,
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
                                            color: isDark ? Colors.white30 : Colors.grey.shade400,
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
          },
        );
      },
    );
  }

  Widget _buildSheetHandle(bool isDark) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSheetHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primary,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primary
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primary
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStatsState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Clear Cache?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will delete temporary image covers, page buffers, and cached network responses. Your bookmarks and reading progression will NOT be deleted.',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Clear Now'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      await _storageService.clearCache();
      await _loadCacheSize();
      if (mounted) {
        AlertBanner.show(
          context,
          'Cache cleared successfully!',
          type: AlertBannerType.success,
        );
      }
    }
  }

  Future<void> _openDownloadedChapters() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    await Navigator.pushNamed(context, AppRoutes.downloadedChapters);
    if (mounted) {
      _loadStorageSizes();
    }
  }

  Widget _buildHeader(bool isDark, User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(context).colorScheme.primary,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? const Icon(Icons.person, size: 32, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Username',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              : null,
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                await authService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                debugPrint('Logout error: $e');
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _handleVersionTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'App Version $_appVersion',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
