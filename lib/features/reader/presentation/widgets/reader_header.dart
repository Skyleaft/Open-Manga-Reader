import 'package:flutter/material.dart';
import 'dart:ui';
import 'reader_status_bar_info.dart';

class ReaderHeader extends StatelessWidget {
  final String mangaTitle;
  final String chapterTitle;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onChapterListTap;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onShowShortcuts;
  final bool isFullscreen;

  const ReaderHeader({
    super.key,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.onBack,
    required this.onSettings,
    this.onChapterListTap,
    this.onToggleFullscreen,
    this.onShowShortcuts,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildGlassIconButton(
                    Icons.arrow_back,
                    onBack,
                    tooltip: 'Back (Esc)',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onChapterListTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    mangaTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          chapterTitle,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 11,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (onChapterListTap != null) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 8),
                    const ReaderStatusBarInfo(),
                  ],
                  if (onToggleFullscreen != null) ...[
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      onToggleFullscreen!,
                      tooltip: 'Toggle Fullscreen (F)',
                    ),
                  ],
                  if (onShowShortcuts != null && !isCompact) ...[
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      Icons.keyboard_alt_outlined,
                      onShowShortcuts!,
                      tooltip: 'Keyboard Shortcuts (?)',
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildGlassIconButton(
                    Icons.settings_outlined,
                    onSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    final button = Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
