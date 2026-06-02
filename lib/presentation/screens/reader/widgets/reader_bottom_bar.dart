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
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented Progress Bar (Full width)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _SegmentedProgressBar(
                  totalPages: totalPages,
                  currentPage: currentPage,
                  onChanged: onProgressChanged,
                  onChangeStart: onProgressChangeStart,
                  onChangeEnd: onProgressChangeEnd,
                ),
              ),
              const SizedBox(height: 10),
              // Navigation and Page Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Chapter Button
                  _buildNavButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: onPreviousChapter,
                    tooltip: 'Previous Chapter',
                  ),
                  
                  // Page Counter Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      'PAGE $currentPage OF $totalPages  •  ${((progress * 100).toInt())}%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  
                  // Next Chapter Button
                  _buildNavButton(
                    icon: Icons.skip_next_rounded,
                    onTap: onNextChapter,
                    tooltip: 'Next Chapter',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
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
            width: 42,
            height: 42,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(_dragProgress * width, 6),
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
                              fontSize: 12,
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
