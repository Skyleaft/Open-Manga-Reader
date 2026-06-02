import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_manga_reader/data/services/auth_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../routes/app_pages.dart';
import '../../../data/models/api_config.dart';

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
    // Wait a frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeConfig = await ApiConfigManager.getActiveApiConfig();
      if (activeConfig == null) {
        if (mounted) {
          Navigator.pushNamed(context, AppRoutes.baseApiSetting);
        }
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        // Navigate to home screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        // Show error message
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
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.backgroundDark.withOpacity(0.7),
                        AppColors.backgroundDark,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
                // Logo and Title Area
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
                            color: AppColors.primary.withOpacity(0.2),
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
                          color: Color(0xFFE2E8F0), // slate-200
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  // Google Button
                  _buildButton(
                    context: context,
                    icon: const FaIcon(FontAwesomeIcons.google),
                    label: _isLoading ? "Signing in..." : "Sign In with Google",
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    backgroundColor: isDark ? AppColors.slate800 : Colors.white,
                    textColor: isDark ? Colors.white : AppColors.slate800,
                  ),
                  const SizedBox(height: 16),

                  const Spacer(),
                  // Footer Terms
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
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side:
                backgroundColor == Colors.white ||
                    backgroundColor == AppColors.slate800
                ? BorderSide(color: Colors.white.withOpacity(0.1))
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
