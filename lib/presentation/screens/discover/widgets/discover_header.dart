import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DiscoverHeader extends StatefulWidget {
  final bool isDark;
  final Function(String) onSearch;
  final VoidCallback onShowQueue;
  final VoidCallback onSearchScrapSource;
  final VoidCallback onFilter;
  final bool hasFilters;
  final Function(String) onSortChanged;
  final VoidCallback onOrderToggle;
  final String currentSortBy;
  final String currentOrderBy;

  const DiscoverHeader({
    super.key,
    required this.isDark,
    required this.onSearch,
    required this.onShowQueue,
    required this.onSearchScrapSource,
    required this.onFilter,
    required this.onSortChanged,
    required this.onOrderToggle,
    required this.currentSortBy,
    required this.currentOrderBy,
    this.hasFilters = false,
  });

  @override
  State<DiscoverHeader> createState() => _DiscoverHeaderState();
}

class _DiscoverHeaderState extends State<DiscoverHeader> {
  Timer? _debounceTimer;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debounceSearch(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discover',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : AppColors.secondary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onSearchScrapSource,
                    icon: const Icon(
                      Icons.search_outlined,
                      color: AppColors.primary,
                    ),
                  ),

                  IconButton(
                    onPressed: widget.onShowQueue,
                    icon: const Icon(
                      Icons.notifications_none,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _debounceSearch,
              decoration: const InputDecoration(
                hintText: 'Search manga, manhwa, artists...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onFilter,
                  child: _buildFilterButton(
                    Icons.filter_list,
                    'Filters',
                    isActive: widget.hasFilters,
                  ),
                ),
                _buildSortPicker(),
                _buildOrderToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    IconData icon,
    String label, {
    bool isActive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.secondary : AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortPicker() {
    final sortOptions = {
      'updatedAt': 'Updated',
      'title': 'Title',
      'totalView': 'Popularity',
      'createdAt': 'Release Date',
    };

    String label = sortOptions[widget.currentSortBy] ?? 'Sort';

    return PopupMenuButton<String>(
      onSelected: widget.onSortChanged,
      itemBuilder: (context) => sortOptions.entries.map((e) {
        return PopupMenuItem(value: e.key, child: Text(e.value));
      }).toList(),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              'Sort: $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: widget.isDark ? Colors.white70 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderToggle() {
    return GestureDetector(
      onTap: widget.onOrderToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          widget.currentOrderBy == 'asc' ? Icons.south : Icons.north,
          size: 18,
          color: widget.isDark ? Colors.white70 : AppColors.primary,
        ),
      ),
    );
  }
}
