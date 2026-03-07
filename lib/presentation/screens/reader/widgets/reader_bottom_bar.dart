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
            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
