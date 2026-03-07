import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final Widget placeholder;
  final Widget errorWidget;
  final bool gaplessPlayback;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    required this.placeholder,
    required this.errorWidget,
    this.gaplessPlayback = true,
  });

  @override
  Widget build(BuildContext context) {
    // WEB
    if (kIsWeb) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        gaplessPlayback: gaplessPlayback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ??
              const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stack) {
          return errorWidget ??
              const Icon(Icons.broken_image, color: Colors.white24);
        },
      );
    }
    // MOBILE
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      placeholder: (context, url) => placeholder,
      errorWidget: (context, url, error) => errorWidget,
    );
  }
}
