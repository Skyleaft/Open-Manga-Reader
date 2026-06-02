import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_manga_reader/core/constants/app_colors.dart';

enum AlertBannerType { success, error, info }

class AlertBanner {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    AlertBannerType type = AlertBannerType.info,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss any existing banner instantly
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _currentEntry = OverlayEntry(
      builder: (context) => AlertBannerWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          dismiss();
        },
      ),
    );

    overlay.insert(_currentEntry!);
  }

  static void dismiss() {
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }
}

class AlertBannerWidget extends StatefulWidget {
  final String message;
  final AlertBannerType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const AlertBannerWidget({
    super.key,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<AlertBannerWidget> createState() => _AlertBannerWidgetState();
}

class _AlertBannerWidgetState extends State<AlertBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _timer;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _controller.forward();

    _timer = Timer(widget.duration, () {
      _close();
    });
  }

  void _close() {
    if (_isDismissed) return;
    _isDismissed = true;
    _timer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accentColor = switch (widget.type) {
      AlertBannerType.success => const Color(0xFF10B981), // Emerald
      AlertBannerType.error => const Color(0xFFEF4444), // Crimson
      AlertBannerType.info => AppColors.primary,
    };

    final IconData icon = switch (widget.type) {
      AlertBannerType.success => Icons.check_circle_rounded,
      AlertBannerType.error => Icons.error_outline_rounded,
      AlertBannerType.info => Icons.info_outline_rounded,
    };

    final Color bgColor = isDark
        ? const Color(0xFF1E293B) // slate-800
        : Colors.white;

    final Color textColor = isDark
        ? const Color(0xFFF1F5F9) // slate-100
        : const Color(0xFF1E293B); // slate-900

    final Color borderColor = isDark
        ? accentColor.withOpacity(0.4)
        : accentColor.withOpacity(0.2);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _timer?.cancel();
                  widget.onDismiss();
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: accentColor, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: textColor.withOpacity(0.5),
                            size: 18,
                          ),
                          onPressed: _close,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
