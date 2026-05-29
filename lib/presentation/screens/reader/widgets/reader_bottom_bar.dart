import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../core/constants/app_colors.dart';

class ReaderBottomBar extends StatelessWidget {
  final double progress;
  final int currentPage;
  final int totalPages;
  final bool isSliderScrolling;
  final ValueChanged<double> onProgressChanged;
  final ValueChanged<double> onProgressChangeStart;
  final ValueChanged<double> onProgressChangeEnd;
  final VoidCallback onNextChapter;
  final VoidCallback onPreviousChapter;
  final bool isAutoScrolling;
  final double autoScrollSpeed;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onSpeedChange;

  const ReaderBottomBar({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.isSliderScrolling,
    required this.onProgressChanged,
    required this.onProgressChangeStart,
    required this.onProgressChangeEnd,
    required this.onNextChapter,
    required this.onPreviousChapter,
    required this.isAutoScrolling,
    required this.autoScrollSpeed,
    required this.onToggleAutoScroll,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 45, 45, 45).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Slider Row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: onPreviousChapter,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white10,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: progress,
                        onChangeStart: onProgressChangeStart,
                        onChanged: onProgressChanged,
                        onChangeEnd: onProgressChangeEnd,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: onNextChapter,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              // Info Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isAutoScrolling
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: onToggleAutoScroll,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          if (isAutoScrolling) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onSpeedChange,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${autoScrollSpeed.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      'PAGE $currentPage OF $totalPages  •  ${((progress * 100).toInt())}%',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
