import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/url_utils.dart';
import 'app_network_image.dart';
import 'dart:math' as math;

class ReaderContentWidget extends StatefulWidget {
  final String? chapterId;
  final List<String> pageUrls;
  final bool isLoading;
  final bool showUI;
  final TransformationController transformationController;
  final ScrollController scrollController;
  final PageController pageController;
  final bool isWebtoonMode;
  final bool isRtlMode;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;
  final GestureTapDownCallback onDoubleTapDown;
  final GestureTapCallback onDoubleTap;
  final VoidCallback onToggleUI;
  final Map<String, String>? httpHeaders;
  final Map<int, double>? pageAspectRatios;
  final void Function(int index, double ratio)? onAspectRatioResolved;
  final bool hasNextChapter;
  final GlobalKey Function(int index)? getPageKey;
  final double defaultAspectRatio;

  const ReaderContentWidget({
    super.key,
    this.chapterId,
    required this.pageUrls,
    required this.isLoading,
    required this.showUI,
    required this.transformationController,
    required this.scrollController,
    required this.pageController,
    required this.isWebtoonMode,
    this.isRtlMode = false,
    required this.onPageChanged,
    required this.onTap,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.onToggleUI,
    this.httpHeaders,
    this.pageAspectRatios,
    this.onAspectRatioResolved,
    this.hasNextChapter = true,
    this.getPageKey,
    this.defaultAspectRatio = 1.4,
  });

  @override
  State<ReaderContentWidget> createState() => _ReaderContentWidgetState();
}

class _ReaderContentWidgetState extends State<ReaderContentWidget> {
  final Set<String> _precachedUrls = {};
  int _lastPrecachedIndex = -1;

  @override
  void didUpdateWidget(covariant ReaderContentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageUrls != widget.pageUrls ||
        oldWidget.chapterId != widget.chapterId) {
      _precachedUrls.clear();
      _lastPrecachedIndex = -1;
    }
  }

  void _precacheNearbyPages(int currentIndex) {
    if (!mounted || widget.pageUrls.isEmpty) return;
    if (_lastPrecachedIndex == currentIndex) return;
    _lastPrecachedIndex = currentIndex;

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = math.min(screenWidth, 800.0);
    final memCacheWidth =
        (contentWidth * devicePixelRatio).round().clamp(400, 1600);

    // Precache next 2 pages and previous 1 page
    for (int offset = -1; offset <= 2; offset++) {
      final targetIndex = currentIndex + offset;
      if (targetIndex >= 0 && targetIndex < widget.pageUrls.length) {
        final rawUrl = widget.pageUrls[targetIndex];
        final url = UrlUtils.sanitizeImageUrl(rawUrl);
        if (!_precachedUrls.contains(url)) {
          _precachedUrls.add(url);
          precacheImage(
            CachedNetworkImageProvider(
              url,
              headers: widget.httpHeaders,
              maxWidth: memCacheWidth,
            ),
            context,
            onError: (exception, stackTrace) {
              try {
                CachedNetworkImageProvider(
                  url,
                  headers: widget.httpHeaders,
                  maxWidth: memCacheWidth,
                ).evict();
              } catch (_) {}
            },
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = math.min(screenWidth, 800.0);

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTapDown: widget.onDoubleTapDown,
        onDoubleTap: widget.onDoubleTap,
        child: widget.isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : widget.isWebtoonMode
            ? InteractiveViewer(
                transformationController: widget.transformationController,
                minScale: 1.0,
                maxScale: 5.0,
                scaleEnabled: false,
                panEnabled:
                    widget.transformationController.value.getMaxScaleOnAxis() >
                    1,
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.none,
                trackpadScrollCausesScale: false,
                child: CustomScrollView(
                  key: PageStorageKey('webtoon_scroll_${widget.chapterId ?? "default"}'),
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1500),
                  controller: widget.scrollController,
                  physics:
                      widget.transformationController.value
                                  .getMaxScaleOnAxis() >
                              1
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                  slivers: [
                    SliverVariedExtentList(
                      itemExtentBuilder: (index, dimensions) {
                        final ratio = widget.pageAspectRatios?[index] ?? widget.defaultAspectRatio;
                        return contentWidth * ratio;
                      },
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final url = widget.pageUrls[index];
                          final ratio = widget.pageAspectRatios?[index] ?? 1.4;
                          final imageHeight = contentWidth * ratio;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _precacheNearbyPages(index);
                          });

                          return RepaintBoundary(
                            child: Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                key: widget.getPageKey?.call(index) ??
                                    GlobalObjectKey('webtoon_${widget.chapterId ?? "default"}_page_$index'),
                                width: contentWidth,
                                child: AppNetworkImage(
                                  imageUrl: url,
                                  httpHeaders: widget.httpHeaders,
                                  fit: BoxFit.fitWidth,
                                  width: contentWidth,
                                  debugLabel:
                                      'P. ${index + 1}/${widget.pageUrls.length} • ${ratio.toStringAsFixed(2)}',
                                  onAspectRatioResolved: (aspect) {
                                    widget.onAspectRatioResolved?.call(index, aspect);
                                  },
                                  gaplessPlayback: true,
                                  placeholder: Container(
                                    height: imageHeight,
                                    width: contentWidth,
                                    color: Colors.black,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: Container(
                                    height: imageHeight,
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount:
                            widget.pageUrls.isEmpty
                                ? 0
                                : widget.pageUrls.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'End of Chapter (${widget.pageUrls.length}/${widget.pageUrls.length})',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (widget.hasNextChapter) ...[
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.isLoading
                                          ? null
                                          : () => widget.onPageChanged(
                                                widget.pageUrls.length,
                                              ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Next Chapter',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Pull up or tap to continue',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'You have reached the latest chapter',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: math.max(
                          160.0,
                          MediaQuery.sizeOf(context).height * 0.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : PageView.builder(
                key: PageStorageKey('paged_view_${widget.chapterId ?? "default"}'),
                controller: widget.pageController,
                reverse: widget.isRtlMode,
                onPageChanged: (index) {
                  _precacheNearbyPages(index);
                  widget.onPageChanged(index);
                },
                itemCount:
                    widget.pageUrls.isEmpty ? 0 : widget.pageUrls.length + 1,
                itemBuilder: (context, index) {
                  if (index == widget.pageUrls.length) {
                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.isLoading
                            ? null
                            : () => widget.onPageChanged(widget.pageUrls.length),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Icon(
                                widget.hasNextChapter
                                    ? Icons.arrow_forward_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              widget.hasNextChapter
                                  ? 'Swipe or tap to load next chapter'
                                  : 'You have reached the latest chapter',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final url = widget.pageUrls[index];
                  return Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: RepaintBoundary(
                        child: AppNetworkImage(
                          imageUrl: url,
                          httpHeaders: widget.httpHeaders,
                          fit: BoxFit.contain,
                          debugLabel: 'P. ${index + 1}/${widget.pageUrls.length}',
                          gaplessPlayback: true,
                          placeholder: Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            color: Colors.black,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
