import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/manga_summary.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/discover_card.dart';
import '../../../../core/widgets/shimmer_box.dart';

class HomeRecommendedSection extends StatelessWidget {
  final List<MangaSummary> recommendedManga;
  final bool isLoading;
  final bool isDark;
  final MangaApiService apiService;
  final void Function(String mangaId, {MangaSummary? summary}) onSelectManga;
  final VoidCallback? onNavigateToDiscover;

  const HomeRecommendedSection({
    super.key,
    required this.recommendedManga,
    required this.isLoading,
    this.isDark = true,
    required this.apiService,
    required this.onSelectManga,
    this.onNavigateToDiscover,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final int crossAxisCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    final double childAspectRatio = isDesktop ? 0.75 : (isTablet ? 0.70 : 0.65);
    final double mainAxisSpacing = isDesktop ? 20 : 14;
    final double crossAxisSpacing = isDesktop ? 16 : 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recommended for You',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '✨ FOR YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onNavigateToDiscover != null)
                TextButton(
                  onPressed: onNavigateToDiscover,
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Grid Content
          if (isLoading)
            _buildSkeletonGrid(
              crossAxisCount,
              childAspectRatio,
              mainAxisSpacing,
              crossAxisSpacing,
            )
          else if (recommendedManga.isEmpty)
            _buildEmptyState()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommendedManga.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: mainAxisSpacing,
                crossAxisSpacing: crossAxisSpacing,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final manga = recommendedManga[index];
                return DiscoverCard(
                  title: manga.title,
                  type: manga.type,
                  latestChapter: manga.latestChapter,
                  views: formatViewCount(manga.totalView),
                  genres: manga.genres ?? [],
                  status: manga.status,
                  rating: manga.rating,
                  heroTag: 'manga-cover-recommended-${manga.id}',
                  localImageUrl: manga.localImageUrl,
                  imageUrl: manga.imageUrl,
                  onTap: () => onSelectManga(manga.id, summary: manga),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid(
    int crossAxisCount,
    double childAspectRatio,
    double mainSpacing,
    double crossSpacing,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: crossAxisCount * 2,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainSpacing,
        crossAxisSpacing: crossSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return const ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 14,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 32,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No recommendations found',
            style: GoogleFonts.inter(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
