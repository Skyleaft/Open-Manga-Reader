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

  const DiscoverHeader({
    super.key,
    required this.isDark,
    required this.onSearch,
    required this.onShowQueue,
    required this.onSearchScrapSource,
    required this.onFilter,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: widget.isDark ? Colors.white : AppColors.secondary,
                    ),
                  ),
                  Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildHeaderIconButton(
                    onPressed: widget.onSearchScrapSource,
                    icon: Icons.cloud_sync_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderIconButton(
                    onPressed: widget.onShowQueue,
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _debounceSearch,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search manga, manhwa...',
                      hintStyle: TextStyle(
                        color: widget.isDark ? Colors.white54 : Colors.grey,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: widget.isDark ? AppColors.primary : Colors.grey,
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterActionIconButton(
                onTap: widget.onFilter,
                isActive: widget.hasFilters,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterActionIconButton({
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [AppColors.primary, Color(0xFFE56B6F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive
              ? null
              : widget.isDark
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 22,
          color: isActive ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
