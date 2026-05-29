import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animated_icon/animated_icon.dart';
import '../constants/app_colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    // Responsive padding and height
    final EdgeInsetsGeometry margin = isDesktop
        ? const EdgeInsets.only(left: 48, right: 48, bottom: 32)
        : isTablet
        ? const EdgeInsets.only(left: 36, right: 36, bottom: 28)
        : const EdgeInsets.only(left: 24, right: 24, bottom: 24);

    final double height = isDesktop
        ? 72
        : isTablet
        ? 68
        : 64;

    // Responsive border radius
    final double borderRadius = isDesktop
        ? 36
        : isTablet
        ? 34
        : 32;

    return Container(
      margin: margin,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color:
                  (isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight)
                      .withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(borderRadius),
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
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    AnimateIcons animateIcon,
    String label,
    bool showLabel,
  ) {
    final isActive = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.primary.withValues(alpha: 0.1),
      highlightColor: AppColors.primary.withValues(alpha: 0.05),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimateIcon(
              key: ValueKey('nav_item_$index'),
              onTap: () => onTap(index),
              iconType: IconType.animatedOnTap,
              height: 24,
              width: 24,
              color: isActive
                  ? AppColors.primary
                  : isDark
                  ? Colors.white70
                  : AppColors.secondary,
              animateIcon: animateIcon,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: SizedBox(
                  width: (isActive || showLabel) ? null : 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.primary
                              : isDark
                              ? Colors.white70
                              : AppColors.secondary,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
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
