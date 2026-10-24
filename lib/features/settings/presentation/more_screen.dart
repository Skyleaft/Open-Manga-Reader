import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../auth/services/auth_service.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../../routes/app_pages.dart';
import '../../download/services/download_service.dart';
import '../../library/services/library_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import 'base_api_setting_screen.dart';
import 'storage_setting_screen.dart';
import 'theme_setting_screen.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/chapters_read_sheet.dart';
import 'widgets/reading_stats_sheet.dart';
import 'widgets/time_spent_sheet.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with AutomaticKeepAliveClientMixin {
  String _appVersion = 'Loading...';
  final _progressionService = getIt<ProgressionService>();
  final _downloadService = getIt<DownloadService>();
  final _apiService = getIt<MangaApiService>();
  final _storageService = getIt<StorageService>();

  String? _currentUid;

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
    _progressionService.addListener(_onProgressionChanged);
    _downloadService.tasksNotifier.addListener(_onDownloadsChanged);
    _loadAppVersion();
    _loadStats();
    _loadStorageSizes();
  }

  @override
  void dispose() {
    _progressionService.removeListener(_onProgressionChanged);
    _downloadService.tasksNotifier.removeListener(_onDownloadsChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (_currentUid != null && _currentUid != uid) {
      _currentUid = uid;
      _loadStats();
      _loadStorageSizes();
    } else {
      _currentUid = uid;
    }
  }

  void _onProgressionChanged() {
    if (!mounted) return;
    _loadStats(silent: true);
  }

  void _onDownloadsChanged() {
    if (!mounted) return;
    _loadStorageSizes();
  }

  Future<void> _loadStorageSizes() async {
    final cacheSize = await _storageService.getCacheSizeBytes();
    int downloadSize = 0;
    int downloadCount = 0;
    try {
      downloadSize = _downloadService.getTotalDownloadedBytes();
      final groups = _downloadService.getDownloadsGroupedByManga();
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

  Future<void> _loadStats({bool silent = false}) async {
    if (!mounted) return;
    if (!silent && _progressions.isEmpty) {
      setState(() => _isLoadingStats = true);
    }
    try {
      final progressions = await _progressionService.getAllProgressions();

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

      // Immediately reflect counts to UI (flicker-free real-time response)
      if (mounted) {
        setState(() {
          _progressions = progressions;
          _totalChaptersRead = totalChapters;
          _totalReadingTimeSeconds = totalSeconds;
          _isLoadingStats = false;
        });
      }

      // Progressively resolve missing manga metadata (covers, titles)
      final detailService = getIt<MangaDetailService>();
      final libraryService = getIt<LibraryService>();
      final detailsMap =
          Map<String, Map<String, dynamic>>.from(_mangaDetailsMap);
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
        } else {
          // Check local cached MangaDetail or Library first before remote network!
          final cachedDetail = await detailService.getDetail(p.mangaId);
          if (cachedDetail != null) {
            detailsMap[p.mangaId] = {
              'title': cachedDetail.title,
              'author': cachedDetail.author,
              'imageUrl': cachedDetail.imageUrl ?? '',
              'localImageUrl': cachedDetail.localImageUrl,
            };
          } else {
            final libManga = await libraryService.getLibraryManga(p.mangaId);
            if (libManga != null) {
              detailsMap[p.mangaId] = {
                'title': libManga.title,
                'author': libManga.author,
                'imageUrl': libManga.imageUrl,
                'localImageUrl': libManga.imageUrl,
              };
            } else {
              missingMangaIds.add(p.mangaId);
            }
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

      if (mounted) {
        setState(() {
          _mangaDetailsMap = detailsMap;
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

    try {
      AlertBanner.show(
        context,
        'Checking for latest updates...',
        type: AlertBannerType.info,
        duration: const Duration(seconds: 2),
      );

      final updateService = getIt<UpdateService>();
      final updateData = await updateService.checkForUpdate();

      if (!mounted) return;

      if (updateData != null && updateData['hasUpdate'] == true) {
        _showUpdateDialog(updateData);
      } else {
        AlertBanner.show(
          context,
          'You are using the latest version ($_appVersion)',
          type: AlertBannerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Failed to check for updates: $e',
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
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async {
            await Future.wait([
              _progressionService.refreshFromApi(),
              _loadStorageSizes(),
            ]);
            await _loadStats(silent: false);
          },
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
                  subtitle:
                      '${themeProvider.themeModeName} • ${themeProvider.currentScheme.name}',
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
                  subtitle: 'Push notifications active',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Notifications are enabled for new chapters & updates',
                      type: AlertBannerType.info,
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'System default (English)',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Language follows your system language settings',
                      type: AlertBannerType.info,
                    );
                  },
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
                  subtitle: 'User guide and documentation',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Visit Open Manga Reader documentation on GitHub for guides',
                      type: AlertBannerType.info,
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'Report Bug',
                  subtitle: 'Submit an issue or feedback',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Submit bug reports and feature requests on GitHub Issues',
                      type: AlertBannerType.info,
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.library_add_outlined,
                  title: 'Request Manga',
                  subtitle: 'Request new sources or titles',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Request new manga sources or extensions on GitHub',
                      type: AlertBannerType.info,
                    );
                  },
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
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Open Manga Reader operates with local-first, privacy-respecting storage',
                      type: AlertBannerType.info,
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {
                    AlertBanner.show(
                      context,
                      'Open source application licensed under GNU GPL v3',
                      type: AlertBannerType.info,
                    );
                  },
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.code,
                  title: 'Open Source Licenses',
                  subtitle: 'View software licenses',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Open Manga Reader',
                      applicationVersion: _appVersion,
                    );
                  },
                ),

                const SizedBox(height: 32),
                _buildFooter(context),
              ],
            ),
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

    final topMangaInfo =
        topManga != null ? _mangaDetailsMap[topManga.mangaId] : null;
    final topMangaTitle = topMangaInfo?['title'] ?? topManga?.manga?.title;
    final hasTopManga = topManga != null &&
        topManga.totalReadingTime > 0 &&
        topMangaTitle != null;

    final avgMinutesPerChapter =
        (_totalChaptersRead > 0 && _totalReadingTimeSeconds > 0)
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary,
                          primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
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
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showReadingStatsDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                          Icon(Icons.chevron_right_rounded,
                              size: 16, color: primary),
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
                      badge: avgMinutesPerChapter > 0
                          ? '~$avgMinutesPerChapter m/ch'
                          : null,
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

              // Highlight Banner (Top Read Manga)
              if (hasTopManga) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _navigateToDetail(topManga!.mangaId),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF475569),
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Top Title: ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: topMangaTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textLight,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' (${_formatReadingTime(topManga.totalReadingTime)})',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600,
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
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade400,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
        _loadStats(silent: true);
      }
    } catch (e) {
      debugPrint('Error navigating to manga detail: $e');
    }
  }

  void _showReadingStatsDialog() {
    HapticFeedback.selectionClick();
    ReadingStatsBottomSheet.show(
      context,
      progressions: _progressions,
      mangaDetailsMap: _mangaDetailsMap,
      onNavigateToDetail: _navigateToDetail,
    );
  }

  void _showTimeSpentDialog() {
    HapticFeedback.selectionClick();
    TimeSpentBottomSheet.show(
      context,
      progressions: _progressions,
      mangaDetailsMap: _mangaDetailsMap,
      onNavigateToDetail: _navigateToDetail,
    );
  }

  void _showChaptersReadDialog() {
    HapticFeedback.selectionClick();
    ChaptersReadBottomSheet.show(
      context,
      progressions: _progressions,
      mangaDetailsMap: _mangaDetailsMap,
      onNavigateToDetail: _navigateToDetail,
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
          trailing:
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
