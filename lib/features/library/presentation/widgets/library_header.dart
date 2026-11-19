import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_pages.dart';
import '../../controllers/library_controller.dart';

class LibraryHeader extends StatelessWidget {
  final bool isDark;
  final String selectedStatus;
  final bool showFavoritesOnly;
  final bool showDownloadedOnly;
  final bool isGridView;
  final LibrarySortOption sortOption;
  final Map<String, int> statusCounts;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onToggleFavorites;
  final VoidCallback onToggleDownloaded;
  final VoidCallback onToggleViewMode;
  final ValueChanged<LibrarySortOption> onSortChanged;

  const LibraryHeader({
    super.key,
    required this.isDark,
    required this.selectedStatus,
    required this.showFavoritesOnly,
    this.showDownloadedOnly = false,
    required this.isGridView,
    required this.sortOption,
    required this.statusCounts,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onToggleFavorites,
    required this.onToggleDownloaded,
    required this.onToggleViewMode,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Library',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: isGridView ? 'List View' : 'Grid View',
                    onPressed: onToggleViewMode,
                    icon: Icon(
                      isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                      size: 22,
                    ),
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  PopupMenuButton<LibrarySortOption>(
                    tooltip: 'Sort Library',
                    initialValue: sortOption,
                    onSelected: onSortChanged,
                    icon: Icon(
                      Icons.sort_rounded,
                      size: 22,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: LibrarySortOption.lastUpdated,
                        child: Text('Recently Active'),
                      ),
                      const PopupMenuItem(
                        value: LibrarySortOption.alphabetical,
                        child: Text('Alphabetical (A-Z)'),
                      ),
                      const PopupMenuItem(
                        value: LibrarySortOption.progress,
                        child: Text('Highest Chapter Read'),
                      ),
                      const PopupMenuItem(
                        value: LibrarySortOption.dateAdded,
                        child: Text('Date Added'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Reading History',
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.history);
                    },
                    icon: const Icon(Icons.history_outlined, size: 22),
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search title or author in library...',
                hintStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFavoriteChip(),
                _buildDownloadedChip(),
                _buildFilterChip('All'),
                _buildFilterChip('Reading'),
                _buildFilterChip('Completed'),
                _buildFilterChip('OnHold'),
                _buildFilterChip('Dropped'),
                _buildFilterChip('PlanToRead'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadedChip() {
    return GestureDetector(
      onTap: onToggleDownloaded,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: showDownloadedOnly
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showDownloadedOnly ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showDownloadedOnly
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              size: 14,
              color: showDownloadedOnly ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Downloaded',
              style: TextStyle(
                color: showDownloadedOnly ? AppColors.primary : Colors.grey,
                fontWeight:
                    showDownloadedOnly ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteChip() {
    return GestureDetector(
      onTap: onToggleFavorites,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: showFavoritesOnly
              ? Colors.red.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showFavoritesOnly ? Colors.red : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              size: 14,
              color: showFavoritesOnly ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Favorites',
              style: TextStyle(
                color: showFavoritesOnly ? Colors.red : Colors.grey,
                fontWeight: showFavoritesOnly ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isActive = selectedStatus == label;
    final int count = statusCounts[label] ?? 0;

    return GestureDetector(
      onTap: () => onStatusChanged(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
