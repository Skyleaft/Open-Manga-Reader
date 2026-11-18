import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/manga_detail.dart';

class MangaCoverViewer extends StatefulWidget {
  final MangaDetail manga;
  final String heroImageUrl;
  final String? heroTag;

  const MangaCoverViewer({
    super.key,
    required this.manga,
    required this.heroImageUrl,
    this.heroTag,
  });

  static Future<void> show(
    BuildContext context, {
    required MangaDetail manga,
    required String heroImageUrl,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: MangaCoverViewer(
              manga: manga,
              heroImageUrl: heroImageUrl,
              heroTag: heroTag,
            ),
          );
        },
      ),
    );
  }

  @override
  State<MangaCoverViewer> createState() => _MangaCoverViewerState();
}

class _MangaCoverViewerState extends State<MangaCoverViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  late final AnimationController _animationController;
  Animation<Matrix4>? _matrixAnimation;

  bool _showControls = true;
  bool _isZoomed = false;
  double _dragOffsetY = 0.0;
  bool _isDragging = false;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_matrixAnimation != null) {
          _transformationController.value = _matrixAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.08;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0.0);
  }

  void _resetZoom() {
    _animateToMatrix(Matrix4.identity());
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) return;

    if (_isZoomed) {
      _resetZoom();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);

      final zoomed = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(x, y, 0.0)
        // ignore: deprecated_member_use
        ..scale(targetScale, targetScale, 1.0);

      _animateToMatrix(zoomed);
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void _close() {
    if (_isZoomed) {
      _resetZoom();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _shareCover() {
    final title = widget.manga.title;
    final url = widget.heroImageUrl;
    // ignore: deprecated_member_use
    Share.share(
      'Cover image for "$title":\n$url',
      subject: 'Cover - $title',
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeroTag =
        widget.heroTag ?? 'manga-detail-poster-${widget.manga.id}';
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate background opacity based on drag offset
    final double dragProgress = (_dragOffsetY.abs() / 300.0).clamp(0.0, 1.0);
    final double bgOpacity = (0.95 * (1.0 - dragProgress * 0.75)).clamp(0.1, 0.95);

    final statusStr = widget.manga.status?.toUpperCase() ?? 'ONGOING';
    final isCompleted = statusStr.contains('COMPLETE');
    final typeStr = widget.manga.type.isNotEmpty
        ? widget.manga.type.toUpperCase()
        : 'MANGA';

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.keyR): _resetZoom,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Dark blur backdrop
              AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                color: Colors.black.withValues(alpha: bgOpacity),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: const SizedBox.expand(),
                ),
              ),

              // Dismiss background tap area
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                ),
              ),

              // Center Zoomable Image with Fluid Drag Dismiss
              Center(
                child: GestureDetector(
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _handleDoubleTap,
                  onVerticalDragStart: _isZoomed
                      ? null
                      : (_) {
                          setState(() {
                            _isDragging = true;
                          });
                        },
                  onVerticalDragUpdate: _isZoomed
                      ? null
                      : (details) {
                          setState(() {
                            _dragOffsetY += details.delta.dy;
                          });
                        },
                  onVerticalDragEnd: _isZoomed
                      ? null
                      : (details) {
                          if (_dragOffsetY.abs() > 100 ||
                              details.primaryVelocity?.abs() != null &&
                                  details.primaryVelocity!.abs() > 800) {
                            _close();
                          } else {
                            setState(() {
                              _dragOffsetY = 0.0;
                              _isDragging = false;
                            });
                          }
                        },
                  child: Transform.translate(
                    offset: Offset(0, _dragOffsetY),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 4.5,
                      clipBehavior: Clip.none,
                      child: Hero(
                        tag: effectiveHeroTag,
                        transitionOnUserGestures: true,
                        flightShuttleBuilder: (
                          flightContext,
                          animation,
                          flightDirection,
                          fromHeroContext,
                          toHeroContext,
                        ) {
                          final Widget flyingWidget =
                              flightDirection == HeroFlightDirection.pop
                                  ? fromHeroContext.widget
                                  : toHeroContext.widget;
                          return Material(
                            color: Colors.transparent,
                            child: flyingWidget,
                          );
                        },
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: mediaQuery.size.width * 0.92,
                            maxHeight: mediaQuery.size.height * 0.78,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: widget.heroImageUrl,
                              fit: BoxFit.contain,
                              placeholder: (context, _) => Container(
                                width: 220,
                                height: 320,
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 220,
                                height: 320,
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[300],
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white60,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
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
                ),
              ),

              // Top Floating Control Bar
              Positioned(
                top: mediaQuery.padding.top + 12,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close Button
                        _buildCircleButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close (Esc)',
                          onPressed: _close,
                        ),

                        // Actions Row (Reset Zoom, Share)
                        Row(
                          children: [
                            if (_isZoomed) ...[
                              _buildCircleButton(
                                icon: Icons.restart_alt_rounded,
                                tooltip: 'Reset Zoom (R)',
                                onPressed: _resetZoom,
                              ),
                              const SizedBox(width: 10),
                            ],
                            _buildCircleButton(
                              icon: Icons.share_rounded,
                              tooltip: 'Share Cover',
                              onPressed: _shareCover,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Info Floating Pill
              Positioned(
                bottom: mediaQuery.padding.bottom + 16,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xCC0F172A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title & Badges
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.manga.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.5,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          typeStr,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.5,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusStr,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (widget.manga.author.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.manga.author,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 6),
                                  // Hint row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pinch_rounded,
                                        size: 13,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Double-tap or pinch to zoom • Drag to dismiss',
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xB30F172A),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: tooltip,
            icon: Icon(icon, color: Colors.white, size: 20),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
