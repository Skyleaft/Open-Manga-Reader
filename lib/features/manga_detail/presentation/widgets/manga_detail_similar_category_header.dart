import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../models/manga_detail.dart';

class MangaDetailSimilarCategoryHeader extends StatelessWidget {
  final MangaDetail manga;
  final int totalCount;
  final bool isLoading;
  final String? selectedStatus;
  final String? selectedType;
  final List<String> selectedGenres;
  final List<String> selectedCategories;
  final VoidCallback onOpenFilter;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onRemoveGenre;
  final VoidCallback onRemoveType;
  final VoidCallback onRemoveStatus;
  final ValueChanged<String> onToggleCategory;
  final VoidCallback onRefresh;

  const MangaDetailSimilarCategoryHeader({
    super.key,
    required this.manga,
    required this.totalCount,
    required this.isLoading,
    this.selectedStatus,
    this.selectedType,
    required this.selectedGenres,
    required this.selectedCategories,
    required this.onOpenFilter,
    required this.onClearFilters,
    required this.onRemoveGenre,
    required this.onRemoveType,
    required this.onRemoveStatus,
    required this.onToggleCategory,
    required this.onRefresh,
  });

  int get filterCount =>
      (selectedStatus != null ? 1 : 0) +
      (selectedType != null ? 1 : 0) +
      selectedGenres.length +
      selectedCategories.length;

  bool get hasFilters => filterCount > 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    final categories = manga.categories ?? [];

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
                  'Similar by Category',
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
                  tooltip: 'Refresh similar category',
                  onPressed: isLoading ? null : onRefresh,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
                // Filter button with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Filter results',
                      onPressed: onOpenFilter,
                      icon: Icon(
                        hasFilters
                            ? Icons.filter_alt_rounded
                            : Icons.filter_alt_outlined,
                        color: hasFilters ? primaryColor : Colors.grey,
                        size: 20,
                      ),
                    ),
                    if (filterCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              '$filterCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 4),
        Text(
          categories.isNotEmpty
              ? 'Find titles matching tropes and categories from this manga.'
              : 'Discover titles categorized similarly to this manga.',
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),

        // Available Manga Categories / Tropes Chips
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategories.contains(cat);

                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) => onToggleCategory(cat),
                  selectedColor: primaryColor.withValues(alpha: 0.22),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? primaryColor : textColor,
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: isSelected
                          ? primaryColor
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],

        // Active filters row
        if (hasFilters) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Active filters:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              if (selectedType != null)
                _buildActiveFilterChip(
                  label: 'Type: $selectedType',
                  onDeleted: onRemoveType,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              if (selectedStatus != null)
                _buildActiveFilterChip(
                  label: 'Status: $selectedStatus',
                  onDeleted: onRemoveStatus,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ...selectedGenres.map(
                (genre) => _buildActiveFilterChip(
                  label: genre,
                  onDeleted: () => onRemoveGenre(genre),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              ...selectedCategories.map(
                (cat) => _buildActiveFilterChip(
                  label: 'Cat: $cat',
                  onDeleted: () => onToggleCategory(cat),
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              TextButton(
                onPressed: onClearFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onDeleted,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isDark ? Colors.white : Colors.black87,
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: onDeleted,
      deleteIconColor: isDark ? Colors.white70 : Colors.black54,
      backgroundColor: primaryColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
    );
  }
}
