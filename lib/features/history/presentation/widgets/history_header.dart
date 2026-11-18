import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';

class HistoryHeader extends StatelessWidget {
  final bool isDark;
  final String selectedFilter;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onClearAll;

  const HistoryHeader({
    super.key,
    required this.isDark,
    required this.selectedFilter,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onRefresh,
    this.onClearAll,
  });

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Reading History'),
        content: const Text(
          'Are you sure you want to clear all your reading history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              onClearAll?.call();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Reading History',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (onClearAll != null)
                IconButton(
                  onPressed: () => _showClearAllConfirmation(context),
                  tooltip: 'Clear history',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_outlined),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search Bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search manga in history...',
                hintStyle: TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('Today'),
                _buildFilterChip('This Week'),
                _buildFilterChip('This Month'),
                _buildFilterChip('In Progress'),
                _buildFilterChip('Completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isActive = selectedFilter == label;
    return GestureDetector(
      onTap: () => onFilterChanged(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

