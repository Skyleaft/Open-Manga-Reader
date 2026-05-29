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
                      size: 22,
                    ),
                    onPressed: onPreviousChapter,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _SegmentedProgressBar(
                        totalPages: totalPages,
                        currentPage: currentPage,
                        onChanged: onProgressChanged,
                        onChangeStart: onProgressChangeStart,
                        onChangeEnd: onProgressChangeEnd,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white70,
                      size: 22,
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
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: isAutoScrolling
                                  ? AppColors.primary
                                  : Colors.white70,
                              size: 24,
                            ),
                            onPressed: onToggleAutoScroll,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: isAutoScrolling
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: GestureDetector(
                                      onTap: onSpeedChange,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${autoScrollSpeed.toStringAsFixed(1)}x',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PAGE $currentPage OF $totalPages  •  ${((progress * 100).toInt())}%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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

class _SegmentedProgressBar extends StatefulWidget {
  final int totalPages;
  final int currentPage;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  const _SegmentedProgressBar({
    required this.totalPages,
    required this.currentPage,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  @override
  State<_SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<_SegmentedProgressBar> {
  double _dragProgress = 0.0;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  void _showOverlay(double width) {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          final hoverPage =
              ((_dragProgress * (widget.totalPages - 1)).round() + 1).clamp(
                1,
                widget.totalPages,
              );
          return Positioned(
            width: 34,
            height: 34,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(_dragProgress * width, 12),
              child: IgnorePointer(
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1.0),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '$hoverPage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(10, 5),
                          painter: _TrianglePainter(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleGesture(Offset localPosition, double width) {
    if (width <= 0 || widget.totalPages <= 1) return;
    double progress = localPosition.dx / width;
    progress = progress.clamp(0.0, 1.0);

    setState(() {
      _dragProgress = progress;
    });

    _showOverlay(width);
    widget.onChanged(progress);
  }

  void _endGesture() {
    _hideOverlay();
    widget.onChangeEnd(0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalPages <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              widget.onChangeStart(0);
              _handleGesture(details.localPosition, width);
            },
            onPanUpdate: (details) {
              _handleGesture(details.localPosition, width);
            },
            onPanEnd: (_) {
              _endGesture();
            },
            onPanCancel: () {
              _endGesture();
            },
            onTapDown: (details) {
              widget.onChangeStart(0);
              _handleGesture(details.localPosition, width);
            },
            onTapUp: (_) {
              _endGesture();
            },
            onTapCancel: () {
              _endGesture();
            },
            child: Container(
              height: 32,
              alignment: Alignment.center,
              child: Row(
                children: List.generate(widget.totalPages, (index) {
                  final isPassed = index < widget.currentPage;
                  final isCurrent = index == (widget.currentPage - 1);

                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.symmetric(
                        horizontal: widget.totalPages > 50 ? 0.5 : 1.5,
                      ),
                      height: isCurrent ? 8.0 : 4.0,
                      decoration: BoxDecoration(
                        color: isPassed ? AppColors.primary : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}
