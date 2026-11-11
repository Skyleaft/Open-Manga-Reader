import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';

class StatusSelectionOption {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const StatusSelectionOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class StatusSelectionSheet {
  static final List<StatusSelectionOption> options = [
    StatusSelectionOption(
      key: 'Reading',
      label: 'Reading',
      icon: Icons.auto_stories_rounded,
      color: AppColors.primary,
    ),
    StatusSelectionOption(
      key: 'PlanToRead',
      label: 'Plan to Read',
      icon: Icons.schedule_rounded,
      color: Color(0xFF3B82F6),
    ),
    StatusSelectionOption(
      key: 'Completed',
      label: 'Completed',
      icon: Icons.task_alt_rounded,
      color: Color(0xFF10B981),
    ),
    StatusSelectionOption(
      key: 'OnHold',
      label: 'On Hold',
      icon: Icons.pause_circle_outline_rounded,
      color: Color(0xFFF59E0B),
    ),
    StatusSelectionOption(
      key: 'Dropped',
      label: 'Dropped',
      icon: Icons.cancel_outlined,
      color: Color(0xFFEF4444),
    ),
  ];

  static String getLabel(String key) {
    for (final opt in options) {
      if (opt.key.toLowerCase() == key.toLowerCase()) {
        return opt.label;
      }
    }
    return key;
  }

  static Color getColor(String key) {
    for (final opt in options) {
      if (opt.key.toLowerCase() == key.toLowerCase()) {
        return opt.color;
      }
    }
    return Colors.grey;
  }

  static Future<String?> show(
    BuildContext context, {
    String? currentStatus,
    String? title,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title ?? 'Set Library Status',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...options.map((opt) {
                final isSelected = currentStatus != null &&
                    opt.key.toLowerCase() == currentStatus.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: isSelected
                        ? opt.color.withValues(alpha: isDark ? 0.2 : 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        AppHaptics.success();
                        Navigator.pop(context, opt.key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: opt.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                opt.icon,
                                color: opt.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                opt.label,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? opt.color
                                      : (isDark
                                          ? Colors.white
                                          : Colors.black87),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: opt.color,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
