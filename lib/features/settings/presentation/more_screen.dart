import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../auth/services/auth_service.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../../routes/app_pages.dart';
import '../../download/services/download_service.dart';
import '../../library/models/library_manga.dart';
import '../../manga_detail/services/manga_detail_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import 'base_api_setting_screen.dart';
import 'storage_setting_screen.dart';
import 'theme_setting_screen.dart';

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
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text(
              'Update Available!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version (${updateData['version']}) is available.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(
                  updateData['body'] ?? 'Performance improvements and bug fixes.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final url = Uri.parse(updateData['url']);
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
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
                icon: Icons.bar_chart_outlined,
                title: 'Reading Statistics',
                onTap: _showReadingStatsDialog,
              ),
              _buildMenuItem(
                context,
                icon: Icons.access_time_outlined,
                title: 'Time Spent',
                onTap: _showTimeSpentDialog,
              ),
              _buildMenuItem(
                context,
                icon: Icons.menu_book_outlined,
                title: 'Chapters Read',
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Stats Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatsSummaryItem(
                label: 'Manga Reading',
                value: '${_progressions.length}',
                icon: Icons.menu_book,
                iconColor: Colors.blue,
              ),
              _buildStatsSummaryItem(
                label: 'Time Spent',
                value: _formatReadingTime(_totalReadingTimeSeconds),
                icon: Icons.access_time,
                iconColor: Colors.orange,
              ),
              _buildStatsSummaryItem(
                label: 'Chapters Read',
                value: '$_totalChaptersRead',
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _showReadingStatsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reading Statistics'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _progressions.isEmpty
                ? const Center(child: Text('No reading stats available.'))
                : () {
                    final sorted = List<MangaProgression>.from(_progressions)
                      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: sorted.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final p = sorted[index];
                        final mangaInfo = _mangaDetailsMap[p.mangaId];
                        final title =
                            mangaInfo?['title'] ?? 'Manga ID: ${p.mangaId}';
                        final author = mangaInfo?['author'] ?? 'Unknown Author';
                        final imageUrl = mangaInfo?['imageUrl'] ?? '';
                        final localImageUrl = mangaInfo?['localImageUrl'];

                        int chaptersCompleted = p.chapterLogs
                            .where((l) => l.isCompleted)
                            .length;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              _apiService.getLocalImageUrl(
                                localImageUrl,
                                imageUrl,
                              ),
                              width: 40,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 40,
                                height: 55,
                                color: Colors.grey,
                                child: const Icon(Icons.broken_image, size: 16),
                              ),
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Chapters completed: $chaptersCompleted',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showTimeSpentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Time Spent Reading'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Reading Time',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatReadingTime(_totalReadingTimeSeconds),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Breakdown by Manga',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _progressions.isEmpty
                      ? const Center(child: Text('No time tracking data.'))
                      : () {
                          final sorted =
                              List<MangaProgression>.from(_progressions)..sort(
                                (a, b) => b.lastReadAt.compareTo(a.lastReadAt),
                              );
                          return ListView.separated(
                            shrinkWrap: true,
                            itemCount: sorted.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final p = sorted[index];
                              final mangaInfo = _mangaDetailsMap[p.mangaId];
                              final title =
                                  mangaInfo?['title'] ??
                                  'Manga ID: ${p.mangaId}';

                              return ListTile(
                                title: Text(
                                  title,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _formatReadingTime(p.totalReadingTime),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          );
                        }(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showChaptersReadDialog() {
    final completedLogs = <Map<String, dynamic>>[];
    for (final p in _progressions) {
      final mangaInfo = _mangaDetailsMap[p.mangaId];
      final mangaTitle = mangaInfo?['title'] ?? 'Manga ID: ${p.mangaId}';
      for (final log in p.chapterLogs) {
        if (log.isCompleted) {
          completedLogs.add({
            'mangaTitle': mangaTitle,
            'chapterNumber': log.chapterNumber,
            'lastReadAt': log.lastReadAt,
          });
        }
      }
    }

    completedLogs.sort(
      (a, b) =>
          (b['lastReadAt'] as DateTime).compareTo(a['lastReadAt'] as DateTime),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chapters Completed'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: completedLogs.isEmpty
                ? const Center(child: Text('No completed chapters logs.'))
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: completedLogs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = completedLogs[index];
                      final date = item['lastReadAt'] as DateTime;
                      final dateStr = '${date.day}/${date.month}/${date.year}';
                      return ListTile(
                        title: Text(
                          '${item['mangaTitle']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Chapter ${item['chapterNumber']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
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
