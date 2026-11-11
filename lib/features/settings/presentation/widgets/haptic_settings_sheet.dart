import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';

class HapticSettingsBottomSheet extends StatefulWidget {
  const HapticSettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HapticSettingsBottomSheet(),
    );
  }

  @override
  State<HapticSettingsBottomSheet> createState() =>
      _HapticSettingsBottomSheetState();
}

class _HapticSettingsBottomSheetState extends State<HapticSettingsBottomSheet> {
  bool _enabled = AppHaptics.isEnabled;
  double _sliderValue = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.vibration_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haptic Feedback',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Interactive tactile responses via HapticKit',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            'Enable Haptic Feedback',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            _enabled
                                ? 'Tactile feedback active on buttons, gestures, and reader'
                                : 'All vibrations and tactile clicks disabled',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          value: _enabled,
                          activeThumbColor: colorScheme.primary,
                          onChanged: (val) async {
                            await AppHaptics.setEnabled(val);
                            setState(() {
                              _enabled = val;
                            });
                          },
                        ),
                      ),
                    ),

                    if (_enabled) ...[
                      const SizedBox(height: 24),
                      Text(
                        'TACTILE PLAYGROUND',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Impact styles
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTestButton(
                            label: 'Light Tap',
                            icon: Icons.touch_app_outlined,
                            onTap: () => AppHaptics.lightImpact(),
                            isDark: isDark,
                          ),
                          _buildTestButton(
                            label: 'Medium Tap',
                            icon: Icons.touch_app_rounded,
                            onTap: () => AppHaptics.mediumImpact(),
                            isDark: isDark,
                          ),
                          _buildTestButton(
                            label: 'Heavy Tap',
                            icon: Icons.pan_tool_alt_rounded,
                            onTap: () => AppHaptics.heavyImpact(),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notification styles
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTestButton(
                            label: 'Success',
                            icon: Icons.check_circle_outline_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => AppHaptics.success(),
                            isDark: isDark,
                          ),
                          _buildTestButton(
                            label: 'Warning',
                            icon: Icons.warning_amber_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: () => AppHaptics.warning(),
                            isDark: isDark,
                          ),
                          _buildTestButton(
                            label: 'Error',
                            icon: Icons.error_outline_rounded,
                            color: AppColors.error,
                            onTap: () => AppHaptics.error(),
                            isDark: isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'INTERACTIVE BOUNCY BUTTON',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: HapticBounce(
                          onTap: () => AppHaptics.success(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tap for Elastic Bounce & Haptic',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'INTERACTIVE HAPTIC SLIDER',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            HapticSlider(
                              value: _sliderValue,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              activeColor: colorScheme.primary,
                              onChanged: (v) {
                                setState(() {
                                  _sliderValue = v;
                                });
                              },
                            ),
                            Text(
                              'Detent Ticks: ${(_sliderValue * 100).toInt()}%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return ActionChip(
      avatar: Icon(icon, size: 16, color: effectiveColor),
      label: Text(label),
      labelStyle: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black87,
      ),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: effectiveColor.withValues(alpha: 0.25),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onPressed: onTap,
    );
  }
}
