import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../core/constants/app_colors.dart';

class ReaderBottomBar extends StatelessWidget {
  final double progress;
  final int currentPage;
  final int totalPages;
  final bool isSliderScrolling;
  final bool isRtlMode;
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
    this.isRtlMode = false,
    required this.onProgressChanged,
    required this.onProgressChangeStart,
    required this.onProgressChangeEnd,
    required this.onNextChapter,
    required this.onPreviousChapter,
  });

  @override
  Widget build(BuildContext context) {
    // In RTL mode, "Previous" button goes to logically earlier chapter which is visually forward or swapped
    final prevChapterAction = isRtlMode ? onNextChapter : onPreviousChapter;
    final nextChapterAction = isRtlMode ? onPreviousChapter : onNextChapter;
    final prevTooltip = isRtlMode ? 'Next Chapter' : 'Previous Chapter';
    final nextTooltip = isRtlMode ? 'Previous Chapter' : 'Next Chapter';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _SegmentedProgressBar(
                  totalPages: totalPages,
                  currentPage: currentPage,
                  isRtlMode: isRtlMode,
                  onChanged: onProgressChanged,
                  onChangeStart: onProgressChangeStart,
                  onChangeEnd: onProgressChangeEnd,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavButton(
                    icon: Icons.skip_previous_rounded,
                    onTap: prevChapterAction,
                    tooltip: prevTooltip,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      'PAGE $currentPage OF $totalPages  •  ${((progress * 100).toInt())}%${isRtlMode ? " (RTL)" : ""}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildNavButton(
                    icon: Icons.skip_next_rounded,
                    onTap: nextChapterAction,
                    tooltip: nextTooltip,
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
        color: Colors.white.withValues(alpha: 0.06),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
  final bool isRtlMode;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  const _SegmentedProgressBar({
    required this.totalPages,
    required this.currentPage,
    this.isRtlMode = false,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  @override
  State<_SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<_SegmentedProgressBar> {
  double _dragProgress = 0.0;
  bool _isDragging = false;
  int? _lastHapticPage;
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
          final visualProgress =
              widget.isRtlMode ? (1.0 - _dragProgress) : _dragProgress;
          final bubbleX = (visualProgress * width).clamp(22.0, width - 22.0);

          return Positioned(
            width: 44,
            height: 44,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(bubbleX, 4),
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
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

  void _startGesture(Offset localPosition, double width) {
    if (width <= 0 || widget.totalPages <= 1) return;
    _isDragging = true;
    _lastHapticPage = null;
    widget.onChangeStart(0);
    HapticFeedback.lightImpact();
    _handleGesture(localPosition, width);
  }

  void _handleGesture(Offset localPosition, double width) {
    if (width <= 0 || widget.totalPages <= 1) return;
    final double rawProgress = (localPosition.dx / width).clamp(0.0, 1.0);
    final double progress = widget.isRtlMode ? (1.0 - rawProgress) : rawProgress;

    final int targetPage =
        ((progress * (widget.totalPages - 1)).round() + 1).clamp(
      1,
      widget.totalPages,
    );

    if (_lastHapticPage != targetPage) {
      _lastHapticPage = targetPage;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragProgress = progress;
    });

    _showOverlay(width);
    widget.onChanged(progress);
  }

  void _endGesture() {
    if (_isDragging) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _isDragging = false;
      _lastHapticPage = null;
    });
    _hideOverlay();
    widget.onChangeEnd(0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalPages <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final activePage = _isDragging
            ? ((_dragProgress * (widget.totalPages - 1)).round() + 1).clamp(
                1,
                widget.totalPages,
              )
            : widget.currentPage;

        final segments = List.generate(widget.totalPages, (index) {
          final isPassed = index < activePage;
          final isCurrent = index == (activePage - 1);

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              margin: EdgeInsets.symmetric(
                horizontal: widget.totalPages > 50 ? 0.5 : 1.5,
              ),
              height: isCurrent
                  ? (_isDragging ? 12.0 : 8.0)
                  : (_isDragging ? 5.0 : 4.0),
              decoration: BoxDecoration(
                color: isPassed
                    ? AppColors.primary
                    : (isCurrent
                        ? AppColors.primary
                        : (_isDragging ? Colors.white38 : Colors.white24)),
                borderRadius:
                    BorderRadius.circular(isCurrent && _isDragging ? 3 : 2),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(
                            alpha: _isDragging ? 0.75 : 0.5,
                          ),
                          blurRadius: _isDragging ? 6 : 4,
                          spreadRadius: _isDragging ? 1.5 : 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        });

        final displaySegments =
            widget.isRtlMode ? segments.reversed.toList() : segments;

        return CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                _startGesture(details.localPosition, width),
            onPanUpdate: (details) =>
                _handleGesture(details.localPosition, width),
            onPanEnd: (_) => _endGesture(),
            onPanCancel: _endGesture,
            onTapDown: (details) =>
                _startGesture(details.localPosition, width),
            onTapUp: (_) => _endGesture(),
            onTapCancel: _endGesture,
            child: Container(
              height: 36,
              alignment: Alignment.center,
              child: Row(
                children: displaySegments,
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
