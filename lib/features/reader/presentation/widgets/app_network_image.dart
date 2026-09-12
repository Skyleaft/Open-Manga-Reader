import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_avif/flutter_avif.dart';
import '../../../../core/utils/url_utils.dart';

class AppNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool gaplessPlayback;
  final Duration? timeout;
  final Map<String, String>? httpHeaders;
  final int? maxHeightDiskCache;
  final int? maxWidthDiskCache;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final ValueChanged<double>? onAspectRatioResolved;
  final String? debugLabel;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.fitWidth,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.gaplessPlayback = true,
    this.timeout = const Duration(seconds: 15),
    this.httpHeaders,
    this.maxHeightDiskCache,
    this.maxWidthDiskCache,
    this.memCacheWidth,
    this.memCacheHeight,
    this.onAspectRatioResolved,
    this.debugLabel,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  int _retryCount = 0;
  bool _isRetrying = false;
  bool _aspectRatioReported = false;
  bool _disableMemCache = false;
  bool _isAvifFallback = false;
  Key _imageKey = UniqueKey();

  String get _effectiveImageUrl => UrlUtils.sanitizeImageUrl(widget.imageUrl);

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryCount = 0;
      _isRetrying = false;
      _aspectRatioReported = false;
      _disableMemCache = false;
      _isAvifFallback = false;
      _imageKey = UniqueKey();
    }
  }

  Future<void> _forceReload() async {
    if (_isRetrying) return;
    final url = _effectiveImageUrl;
    setState(() {
      _isRetrying = true;
      _retryCount++;
      _disableMemCache = true; // Always disable memCache on manual retry
    });

    try {
      await CachedNetworkImageProvider(
        url,
        headers: widget.httpHeaders,
      ).evict();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _imageKey = UniqueKey();
        _isRetrying = false;
      });
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          height: widget.width != null ? widget.width! * 1.4 : null,
          width: widget.width,
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white24,
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    if (widget.errorWidget != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          widget.errorWidget!,
          _buildRetryButton(),
        ],
      );
    }

    return Container(
      height: widget.width != null ? widget.width! * 1.2 : null,
      width: widget.width,
      color: const Color(0xFF141414),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image_rounded,
            color: Colors.white30,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_retryCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Retried $_retryCount time(s)',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildRetryButton(),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isRetrying ? null : _forceReload,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRetrying)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                _isRetrying ? 'Retrying...' : 'Tap to Retry',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapDebugLabel(Widget child) {
    if (kDebugMode &&
        widget.debugLabel != null &&
        widget.debugLabel!.isNotEmpty) {
      return Stack(
        children: [
          child,
          Positioned(
            top: 8,
            right: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.debugLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final url = _effectiveImageUrl;

    final bool isLocalFile = UrlUtils.isLocalFilePath(url);
    if (isLocalFile) {
      final normalizedPath = UrlUtils.normalizeLocalFilePath(url);
      final file = File(normalizedPath);
      final fileWidget = Image.file(
        file,
        key: _imageKey,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: widget.gaplessPlayback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null &&
              !_aspectRatioReported &&
              widget.onAspectRatioResolved != null) {
            final stream = FileImage(file).resolve(const ImageConfiguration());
            late final ImageStreamListener listener;
            listener = ImageStreamListener(
              (info, _) {
                final w = info.image.width;
                final h = info.image.height;
                if (w > 0 && mounted && !_aspectRatioReported) {
                  _aspectRatioReported = true;
                  widget.onAspectRatioResolved?.call(h / w);
                }
                stream.removeListener(listener);
              },
              onError: (_, _) {
                stream.removeListener(listener);
              },
            );
            stream.addListener(listener);
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('🖼️ [LOCAL IMAGE ERR] $url -> Error: $error');
          }
          return _buildErrorWidget();
        },
      );
      return _wrapDebugLabel(fileWidget);
    }

    if (_isAvifFallback) {
      final avifWidget = CachedNetworkAvifImage(
        url,
        key: _imageKey,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        headers: widget.httpHeaders,
        gaplessPlayback: widget.gaplessPlayback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null &&
              !_aspectRatioReported &&
              widget.onAspectRatioResolved != null) {
            final stream = CachedNetworkAvifImageProvider(
              url,
              headers: widget.httpHeaders,
            ).resolve(const ImageConfiguration());
            late final ImageStreamListener listener;
            listener = ImageStreamListener(
              (info, _) {
                final w = info.image.width;
                final h = info.image.height;
                if (w > 0 && mounted && !_aspectRatioReported) {
                  _aspectRatioReported = true;
                  widget.onAspectRatioResolved?.call(h / w);
                }
                stream.removeListener(listener);
              },
              onError: (_, _) {
                stream.removeListener(listener);
              },
            );
            stream.addListener(listener);
          }
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('🖼️ [AVIF ERR] $url -> Error: $error');
          }
          return _buildErrorWidget();
        },
      );

      return _wrapDebugLabel(avifWidget);
    }

    final imageWidget = CachedNetworkImage(
      key: _imageKey,
      imageUrl: url,
      httpHeaders: widget.httpHeaders,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: _disableMemCache ? null : widget.memCacheWidth,
      memCacheHeight: _disableMemCache ? null : widget.memCacheHeight,
      maxHeightDiskCache: widget.maxHeightDiskCache,
      maxWidthDiskCache: widget.maxWidthDiskCache,
      errorListener: (error) {
        if (kDebugMode) {
          debugPrint('🖼️ [IMAGE ERR] $url -> Error: $error (switching to AVIF decoder)');
        }
        if (!_isAvifFallback) {
          if (mounted) {
            setState(() {
              _isAvifFallback = true;
              _imageKey = UniqueKey();
            });
            return;
          }
        }
        // Evict corrupted/failed image from cache so retry or next load can re-fetch cleanly
        try {
          CachedNetworkImageProvider(
            url,
            headers: widget.httpHeaders,
          ).evict();
        } catch (_) {}
      },
      imageBuilder: widget.onAspectRatioResolved != null
          ? (context, imageProvider) {
              if (!_aspectRatioReported) {
                final stream = imageProvider.resolve(const ImageConfiguration());
                late final ImageStreamListener listener;
                listener = ImageStreamListener(
                  (info, _) {
                    final w = info.image.width;
                    final h = info.image.height;
                    if (w > 0 && mounted && !_aspectRatioReported) {
                      _aspectRatioReported = true;
                      widget.onAspectRatioResolved?.call(h / w);
                    }
                    stream.removeListener(listener);
                  },
                  onError: (exception, stackTrace) {
                    stream.removeListener(listener);
                    try {
                      CachedNetworkImageProvider(
                        url,
                        headers: widget.httpHeaders,
                      ).evict();
                    } catch (_) {}
                  },
                );
                stream.addListener(listener);
              }
              return Image(
                image: imageProvider,
                fit: widget.fit,
                width: widget.width,
                height: widget.height,
                gaplessPlayback: widget.gaplessPlayback,
                errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
              );
            }
          : null,
      placeholder: (context, url) => _buildPlaceholder(),
      errorBuilder: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
    );

    return _wrapDebugLabel(imageWidget);
  }
}
