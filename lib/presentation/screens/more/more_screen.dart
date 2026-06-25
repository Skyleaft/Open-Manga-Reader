import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/services/auth_service.dart';
import 'base_api_setting_screen.dart';
import 'package:my_manga_reader/data/services/progression_service.dart';
import 'package:my_manga_reader/data/services/manga_api_service.dart';
import 'package:my_manga_reader/data/models/progression.dart';
import 'package:my_manga_reader/data/models/library_manga.dart';
import 'package:my_manga_reader/core/di/injection.dart';
import 'dart:async';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _appVersion = 'Loading...';
  final _progressionService = getIt<ProgressionService>();
  final _apiService = getIt<MangaApiService>();

  List<MangaProgression> _progressions = [];
  Map<String, Map<String, dynamic>> _mangaDetailsMap = {};
  bool _isLoadingStats = true;
  int _totalChaptersRead = 0;
  int _totalReadingTimeSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStats = true);
    try {
      final progressions = await _progressionService.getAllProgressions();

      final libraryData = await _apiService.getUserLibrary();
      final libraryMap = <String, LibraryManga>{};
      for (final json in libraryData) {
        try {
          final manga = LibraryManga.fromMap(json);
          libraryMap[manga.id] = manga;
        } catch (_) {}
      }

      final uniqueMangaIds = progressions.map((p) => p.mangaId).toSet();
      final Map<String, Map<String, dynamic>> detailsMap = {};

      await Future.wait(
        uniqueMangaIds.map((mangaId) async {
          try {
            final libManga = libraryMap[mangaId];
            if (libManga != null) {
              detailsMap[mangaId] = {
                'title': libManga.title,
                'author': libManga.author,
                'imageUrl': libManga.imageUrl,
                'localImageUrl': null,
              };
            } else {
              final detailJson = await _apiService.getMangaDetail(mangaId);
              detailsMap[mangaId] = {
                'title': detailJson['title'] ?? 'Unknown Title',
                'author': detailJson['author'] ?? 'Unknown Author',
                'imageUrl': detailJson['imageUrl'] ?? '',
                'localImageUrl': detailJson['localImageUrl'],
              };
            }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
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
                onTap: () {},
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
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Cache',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.data_usage_outlined,
                title: 'Storage Usage',
                onTap: () {},
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
                onTap: () {},
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
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _progressions.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final p = _progressions[index];
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
                        leading: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _apiService.getLocalImageUrl(
                                    localImageUrl,
                                    imageUrl,
                                  ),
                                  width: 40,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 40,
                                    height: 55,
                                    color: Colors.grey,
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 40,
                                height: 55,
                                color: Colors.grey,
                                child: const Icon(Icons.book, size: 16),
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
                            Text(author, style: const TextStyle(fontSize: 12)),
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
                    color: AppColors.primary.withOpacity(0.1),
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _progressions.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final p = _progressions[index];
                            final mangaInfo = _mangaDetailsMap[p.mangaId];
                            final title =
                                mangaInfo?['title'] ?? 'Manga ID: ${p.mangaId}';

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
                        ),
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

  Widget _buildHeader(bool isDark, User? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary,
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
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
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
                // Navigate to login screen
                Navigator.pushReplacementNamed(context, '/login');
              } catch (e) {
                // Handle error
                print('Logout error: $e');
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
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'App Version $_appVersion',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
