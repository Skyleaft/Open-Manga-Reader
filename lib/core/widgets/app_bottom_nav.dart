import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/haptic_service.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Responsive padding and height
    final EdgeInsetsGeometry margin = isDesktop
        ? const EdgeInsets.only(left: 32, right: 32, bottom: 28)
        : isTablet
        ? const EdgeInsets.only(left: 28, right: 28, bottom: 24)
        : const EdgeInsets.only(left: 20, right: 20, bottom: 20);

    final double height = isDesktop
        ? 68
        : isTablet
        ? 66
        : 64;

    final double borderRadius = isDesktop
        ? 34
        : isTablet
        ? 33
        : 32;

    final Color navBgColor = (isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.75));

    final Color navBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          margin: margin,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              if (isDark)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(color: navBorderColor, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      context,
                      0,
                      AnimateIcons.home,
                      'Home',
                      isTablet || isDesktop,
                    ),
                    _buildNavItem(
                      context,
                      1,
                      AnimateIcons.bookmark,
                      'Library',
                      isTablet || isDesktop,
                    ),
                    _buildNavItem(
                      context,
                      2,
                      AnimateIcons.compass,
                      'Discover',
                      isTablet || isDesktop,
                    ),
                    _buildNavItem(
                      context,
                      3,
                      AnimateIcons.circlesMenu3,
                      'More',
                      isTablet || isDesktop,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    AnimateIcons animateIcon,
    String label,
    bool showLabelAlways,
  ) {
    final isActive = currentIndex == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap(index);
      },
      borderRadius: BorderRadius.circular(24),
      splashColor: colorScheme.primary.withValues(alpha: 0.15),
      highlightColor: colorScheme.primary.withValues(alpha: 0.08),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: AnimateIcon(
                key: ValueKey('nav_item_$index'),
                onTap: () {
                  AppHaptics.selection();
                  onTap(index);
                },
                iconType: IconType.animatedOnTap,
                height: 22,
                width: 22,
                color: isActive
                    ? colorScheme.primary
                    : isDark
                    ? Colors.white60
                    : AppColors.secondary,
                animateIcon: animateIcon,
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: (isActive || showLabelAlways) ? null : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          color: isActive
                              ? colorScheme.primary
                              : isDark
                              ? Colors.white60
                              : AppColors.secondary,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
