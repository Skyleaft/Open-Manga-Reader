import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

class AppNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final Widget placeholder;
  final Widget errorWidget;
  final bool gaplessPlayback;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.fitWidth,
    this.width,
    required this.placeholder,
    required this.errorWidget,
    this.gaplessPlayback = true,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  double? _aspectRatio;

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void dispose() {
    if (_imageStreamListener != null) {
      _imageStream?.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  void _resolveImage() {
    if (_imageStreamListener != null) {
      _imageStream?.removeListener(_imageStreamListener!);
    }

    final provider = CachedNetworkImageProvider(widget.imageUrl);
    _imageStream = provider.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener((info, _) {
      final ratio =
          info.image.width.toDouble() / info.image.height.toDouble();

      if (mounted) {
        setState(() {
          _aspectRatio = ratio;
        });
      }
    });

    _imageStream?.addListener(_imageStreamListener!);
  }

  @override
  Widget build(BuildContext context) {
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
        errorWidget: (context, url, error) => widget.errorWidget,
      ),
    );
  }
}
