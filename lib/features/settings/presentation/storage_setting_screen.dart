import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../routes/app_pages.dart';
import '../services/storage_service.dart';

class StorageSettingScreen extends StatefulWidget {
  const StorageSettingScreen({super.key});

  @override
  State<StorageSettingScreen> createState() => _StorageSettingScreenState();
}

class _StorageSettingScreenState extends State<StorageSettingScreen> {
  final StorageService _storageService = getIt<StorageService>();

  StorageUsageInfo? _usageInfo;
  bool _isLoading = true;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    setState(() => _isLoading = true);
    final usage = await _storageService.getStorageUsage();
    if (mounted) {
      setState(() {
        _usageInfo = usage;
        _isLoading = false;
      });
    }
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
          title: Text(
            'Clear Cache?',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will delete temporary image covers, page buffers, and cached network responses. Your bookmarks and reading progression will NOT be deleted.',
            style: GoogleFonts.inter(
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
      setState(() => _isClearing = true);
      HapticFeedback.mediumImpact();
      await _storageService.clearCache();
      await Future.delayed(const Duration(milliseconds: 400));
      await _loadStorageUsage();
      if (mounted) {
        setState(() => _isClearing = false);
        AlertBanner.show(
          context,
          'Cache cleared successfully!',
          type: AlertBannerType.success,
        );
      }
    }
  }

  Future<void> _openDownloadsManager() async {
    HapticFeedback.selectionClick();
    await Navigator.pushNamed(context, AppRoutes.downloadedChapters);
    if (mounted) {
      _loadStorageUsage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final totalBytes = _usageInfo?.totalBytes ?? 0;
    final cacheBytes = _usageInfo?.cacheBytes ?? 0;
    final downloadsBytes = _usageInfo?.downloadsBytes ?? 0;
    final dataBytes = _usageInfo?.dataBytes ?? 0;

    final cacheRatio = totalBytes > 0 ? (cacheBytes / totalBytes) : 0.0;
    final downloadsRatio = totalBytes > 0 ? (downloadsBytes / totalBytes) : 0.0;
    final dataRatio = totalBytes > 0 ? (dataBytes / totalBytes) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Storage & Cache',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh storage usage',
            onPressed: _isLoading || _isClearing ? null : _loadStorageUsage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStorageUsage,
        color: colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Total Storage Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Storage Used',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      if (_isLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      else
                        Text(
                          StorageService.formatBytes(totalBytes),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Segmented Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 10,
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.06),
                      child: Row(
                        children: [
                          if (cacheRatio > 0)
                            Expanded(
                              flex: (cacheRatio * 1000).toInt().clamp(1, 1000),
                              child: Container(color: colorScheme.primary),
                            ),
                          if (downloadsRatio > 0)
                            Expanded(
                              flex: (downloadsRatio * 1000).toInt().clamp(1, 1000),
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (dataRatio > 0)
                            Expanded(
                              flex: (dataRatio * 1000).toInt().clamp(1, 1000),
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend Row
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildLegendItem(
                        color: colorScheme.primary,
                        label: 'Cache',
                        size: StorageService.formatBytes(cacheBytes),
                        isDark: isDark,
                      ),
                      _buildLegendItem(
                        color: const Color(0xFF10B981),
                        label: 'Downloads',
                        size: StorageService.formatBytes(downloadsBytes),
                        isDark: isDark,
                      ),
                      _buildLegendItem(
                        color: const Color(0xFFF59E0B),
                        label: 'Local Data',
                        size: StorageService.formatBytes(dataBytes),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Storage Breakdown', isDark),
            const SizedBox(height: 12),

            // Item 1: Cache
            _buildStorageDetailTile(
              context,
              icon: Icons.cleaning_services_rounded,
              iconColor: colorScheme.primary,
              title: 'Image & Web Cache',
              subtitle:
                  'Covers, preview thumbnails, and temporary network response cache.',
              sizeString: StorageService.formatBytes(cacheBytes),
              trailingButton: ElevatedButton(
                onPressed: _isClearing || cacheBytes == 0
                    ? null
                    : _handleClearCache,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isClearing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Text(
                        'Clear',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // Item 2: Downloads
            _buildStorageDetailTile(
              context,
              icon: Icons.download_done_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Downloaded Chapters',
              subtitle:
                  'Offline saved chapters and volume bundles for reading without internet.',
              sizeString: StorageService.formatBytes(downloadsBytes),
              trailingButton: ElevatedButton(
                onPressed: _openDownloadsManager,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF10B981).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF10B981),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              isDark: isDark,
            ),

            const SizedBox(height: 12),

            // Item 3: Local Data & Preferences
            _buildStorageDetailTile(
              context,
              icon: Icons.storage_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'App Data & History',
              subtitle:
                  'Local progression database, library bookmarks, and app preferences.',
              sizeString: StorageService.formatBytes(dataBytes),
              isDark: isDark,
            ),

            const SizedBox(height: 24),
            // Quick Clean Button at Bottom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClearing || cacheBytes == 0
                    ? null
                    : _handleClearCache,
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                label: Text(
                  cacheBytes > 0
                      ? 'Clear Image & Web Cache (${StorageService.formatBytes(cacheBytes)})'
                      : 'Cache is Clean',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : Colors.black54,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String size,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          size,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStorageDetailTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String sizeString,
    String? badgeText,
    Widget? trailingButton,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (badgeText != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          sizeString,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                if (trailingButton != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailingButton,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
