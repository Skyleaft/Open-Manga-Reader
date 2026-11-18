import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import '../constants/app_colors.dart';
import '../network/manga_api_service.dart';
import '../di/injection.dart';

class MangaCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? localImageUrl;
  final int currentChapter;
  final int totalChapters;
  final double progress;
  final bool isCompleted;
  final String? type;
  final String? status;
  final List<String>? genres;
  final String? heroTag;
  final VoidCallback? onTap;

  const MangaCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.localImageUrl,
    required this.currentChapter,
    required this.totalChapters,
    required this.progress,
    this.isCompleted = false,
    this.type,
    this.status,
    this.genres,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String displayUrl = getIt<MangaApiService>().getLocalImageUrl(
      localImageUrl,
      imageUrl,
    );

    Widget coverContainer = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (displayUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: displayUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                maxWidthDiskCache: 600,
                errorBuilder: (context, url, error) =>
                    _buildPlaceholder(),
                placeholder: (context, url) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),

            // Status Badge (Top Left)
            if (status != null && status!.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: switch (status!.toLowerCase()) {
                      'reading' => Colors.green.withValues(alpha: 0.8),
                      'completed' => Colors.blue.withValues(alpha: 0.8),
                      'onhold' => Colors.orange.withValues(alpha: 0.8),
                      'dropped' => Colors.red.withValues(alpha: 0.8),
                      'plantoread' => Colors.purple.withValues(alpha: 0.8),
                      _ => Colors.grey.withValues(alpha: 0.8),
                    },
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Type Badge (Top Right)
            if (type != null && type!.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Progress Bar (Bottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.secondary : AppColors.primary,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      coverContainer = Hero(
        tag: heroTag!,
        transitionOnUserGestures: true,
        createRectTween: (begin, end) =>
            MaterialRectArcTween(begin: begin, end: end),
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
        child: coverContainer,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: coverContainer),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),

          // Progress text / Chapters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ch. $currentChapter / $totalChapters',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'DONE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[850],
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 32,
        ),
      ),
    );
  }
}
