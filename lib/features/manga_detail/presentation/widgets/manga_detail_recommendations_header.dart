import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/manga_detail.dart';

class MangaDetailRecommendationsHeader extends StatelessWidget {
  final MangaDetail manga;
  final int totalCount;
  final bool isLoading;
  final String? selectedStatus;
  final String? selectedType;
  final List<String> selectedGenres;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onRemoveGenre;
  final VoidCallback onRemoveType;
  final VoidCallback onRemoveStatus;
  final ValueChanged<String> onQuickToggleGenre;
  final VoidCallback onRefresh;

  const MangaDetailRecommendationsHeader({
    super.key,
    required this.manga,
    required this.totalCount,
    required this.isLoading,
    this.selectedStatus,
    this.selectedType,
    required this.selectedGenres,
    required this.onOpenFilter,
    required this.onClearFilters,
    required this.onRemoveGenre,
    required this.onRemoveType,
    required this.onRemoveStatus,
    required this.onQuickToggleGenre,
    required this.onRefresh,
  });

  int get filterCount =>
      (selectedStatus != null ? 1 : 0) +
      (selectedType != null ? 1 : 0) +
      selectedGenres.length;

  bool get hasFilters => filterCount > 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    final mangaGenres = manga.genres ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main row: Title + Count + Filter button + Refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Similar Manga',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                if (!isLoading && totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Refresh recommendations',
                  onPressed: isLoading ? null : onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                // Filter Button with Badge
                InkWell(
                  onTap: onOpenFilter,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasFilters
                          ? primaryColor
                          : (isDark
                              ? AppColors.slate700.withValues(alpha: 0.4)
                              : AppColors.primary.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasFilters
                            ? primaryColor
                            : primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: hasFilters ? Colors.white : primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hasFilters ? 'Filtered ($filterCount)' : 'Filter',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: hasFilters ? Colors.white : primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Horizontal filter chips / quick picks bar
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (hasFilters) ...[
                // Clear all chip
                GestureDetector(
                  onTap: onClearFilters,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Clear all',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Active Status Chip
                if (selectedStatus != null)
                  _buildActiveChip(
                    label: 'Status: $selectedStatus',
                    onDelete: onRemoveStatus,
                    isDark: isDark,
                  ),

                // Active Type Chip
                if (selectedType != null)
                  _buildActiveChip(
                    label: 'Type: $selectedType',
                    onDelete: onRemoveType,
                    isDark: isDark,
                  ),

                // Active Genre Chips
                ...selectedGenres.map(
                  (genre) => _buildActiveChip(
                    label: genre,
                    onDelete: () => onRemoveGenre(genre),
                    isDark: isDark,
                  ),
                ),
              ] else ...[
                // Quick Genre picks from current manga
                if (mangaGenres.isNotEmpty)
                  ...mangaGenres.map(
                    (genre) => GestureDetector(
                      onTap: () => onQuickToggleGenre(genre),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.slate800
                              : AppColors.slate100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.slate700
                                : AppColors.slate200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              genre,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveChip({
    required String label,
    required VoidCallback onDelete,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
