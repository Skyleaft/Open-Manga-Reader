import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_config.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../routes/app_pages.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkApiConfig();
  }

  Future<void> _checkApiConfig() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeConfig = await ApiConfigManager.getActiveApiConfig();
      if (activeConfig == null || activeConfig.baseUrl.trim().isEmpty) {
        if (mounted) {
          AlertBanner.show(
            context,
            'Please configure an API server first.',
            type: AlertBannerType.info,
          );
          Navigator.pushNamed(context, AppRoutes.baseApiSetting);
        }
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    // Block sign in if Base API is not configured
    final activeConfig = await ApiConfigManager.getActiveApiConfig();
    final configs = await ApiConfigManager.loadApiConfigs();
    if (activeConfig == null ||
        configs.isEmpty ||
        activeConfig.baseUrl.trim().isEmpty) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Base API is not configured. Please set up an API server first.',
          type: AlertBannerType.warning,
        );
        Navigator.pushNamed(context, AppRoutes.baseApiSetting);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        if (mounted) {
          AlertBanner.show(
            context,
            'Failed to sign in with Google',
            type: AlertBannerType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Error: $e',
          type: AlertBannerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image Section
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  "https://lh3.googleusercontent.com/aida-public/AB6AXuDaclD9kaU0jo14UJv7wetUbUYR1scVCtpNC_5GGaiZRUvrVTneegqaU-44Na3-CnaVTVXpbA4CP7Ur4u-zHkjj1UnUprtL4Nmmtx536vpV-2Q55lWe9ZKxddIOfREhIaw-U5PLmDmj_sb4NKCoNTY6Bf97g6CThzMsf0iyXSRkDSLgaWOy0lqCIyUMNgmOVyz3NFms5z4-xe3CMsBy7KeSpWo_F_OURnixxp2HmCDy2IcAiC8jPC1TJ-vBuMo2V9EA3hW9MieGObZQ",
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.backgroundDark.withValues(alpha: 0.7),
                        AppColors.backgroundDark,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1.0,
                          color: Colors.white,
                        ),
                        children: [
                          const TextSpan(text: "My"),
                          TextSpan(
                            text: "KomikID",
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 8,
                      ),
                      child: Text(
                        "Immerse yourself in infinite worlds and epic tales.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ],
            ),
          ),

          // Interactive Section
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _buildButton(
                    context: context,
                    icon: const FaIcon(FontAwesomeIcons.google),
                    label: _isLoading ? "Signing in..." : "Sign In with Google",
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    backgroundColor: isDark ? AppColors.slate800 : Colors.white,
                    textColor: isDark ? Colors.white : AppColors.slate800,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.baseApiSetting);
                    },
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      "Configure API Server",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : AppColors.slate500,
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(text: "By continuing, you agree to our "),
                        TextSpan(
                          text: "Terms of Service",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: "."),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Top Settings Action Button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                    tooltip: 'API Settings',
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.baseApiSetting);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool hasShadow = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: hasShadow ? 8 : 0,
          shadowColor: hasShadow
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: backgroundColor == Colors.white ||
                    backgroundColor == AppColors.slate800
                ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
