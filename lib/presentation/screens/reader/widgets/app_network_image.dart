import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

class AppNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final Widget placeholder;
  final Widget errorWidget;
  final bool gaplessPlayback;
  final Duration? timeout;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.fitWidth,
    this.width,
    required this.placeholder,
    required this.errorWidget,
    this.gaplessPlayback = true,
    this.timeout = const Duration(seconds: 15),
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  double? _aspectRatio;

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Timer? _timeoutTimer;
  bool _isErrorOrTimeout = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    if (_imageStreamListener != null) {
      _imageStream?.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  void _resolveImage() {
    _timeoutTimer?.cancel();
    if (_imageStreamListener != null) {
      _imageStream?.removeListener(_imageStreamListener!);
    }

    setState(() {
      _isErrorOrTimeout = false;
    });

    if (widget.timeout != null) {
      _timeoutTimer = Timer(widget.timeout!, () {
        if (mounted && _aspectRatio == null) {
          setState(() {
            _isErrorOrTimeout = true;
          });
        }
      });
    }

    final provider = CachedNetworkImageProvider(widget.imageUrl);
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener((info, _) {
      _timeoutTimer?.cancel();
      final ratio =
          info.image.width.toDouble() / info.image.height.toDouble();

      if (mounted) {
        setState(() {
          _aspectRatio = ratio;
        });
      }
    }, onError: (dynamic exception, StackTrace? stackTrace) {
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isErrorOrTimeout = true;
        });
      }
    });

    _imageStream?.addListener(_imageStreamListener!);
  }

  void _forceReload() {
    CachedNetworkImageProvider(widget.imageUrl).evict().then((_) {
      if (mounted) {
        _resolveImage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isErrorOrTimeout) {
      return Stack(
        alignment: Alignment.center,
        children: [
          widget.errorWidget,
          ElevatedButton.icon(
            onPressed: _forceReload,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
          ),
        ],
      );
    }

    if (_aspectRatio == null) {
      return widget.placeholder;
    }

    return AspectRatio(
      aspectRatio: _aspectRatio!,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: widget.fit,
        width: widget.width,
        placeholder: (context, url) => widget.placeholder,
        errorWidget: (context, url, error) {
          return Stack(
            alignment: Alignment.center,
            children: [
              widget.errorWidget,
              ElevatedButton.icon(
                onPressed: _forceReload,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
            ],
          );
        },
      ),
    );
  }
}
