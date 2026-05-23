import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/services/auth_service.dart';
import 'base_api_setting_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
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
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.access_time_outlined,
                title: 'Time Spent',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.menu_book_outlined,
                title: 'Chapters Read',
                onTap: () {},
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
