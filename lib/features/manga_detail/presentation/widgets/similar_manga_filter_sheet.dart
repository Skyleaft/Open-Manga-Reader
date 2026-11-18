import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/manga_api_service.dart';

class SimilarMangaFilterSheet extends StatefulWidget {
  final List<String> initialGenres;
  final String? initialType;
  final String? initialStatus;
  final List<String> mangaGenres;
  final Function(
    List<String> genres,
    String? type,
    String? status,
  ) onApply;

  const SimilarMangaFilterSheet({
    super.key,
    required this.initialGenres,
    this.initialType,
    this.initialStatus,
    this.mangaGenres = const [],
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> currentGenres,
    String? currentType,
    String? currentStatus,
    List<String> mangaGenres = const [],
    required Function(List<String> genres, String? type, String? status) onApply,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.slate200,
          ),
        ),
        child: SimilarMangaFilterSheet(
          initialGenres: currentGenres,
          initialType: currentType,
          initialStatus: currentStatus,
          mangaGenres: mangaGenres,
          onApply: onApply,
        ),
      ),
    );
  }

  @override
  State<SimilarMangaFilterSheet> createState() =>
      _SimilarMangaFilterSheetState();
}

class _SimilarMangaFilterSheetState extends State<SimilarMangaFilterSheet> {
  final MangaApiService _apiService = getIt<MangaApiService>();

  List<String> _allGenres = [];
  List<String> _allTypes = [];
  final List<String> _statuses = [
    'Ongoing',
    'Completed',
    'On Hiatus',
    'Discontinued',
    'Unknown',
  ];

  bool _isLoading = true;
  String? _error;
  String _genreSearchQuery = '';

  late List<String> _selectedGenres;
  String? _selectedType;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedGenres = List.from(widget.initialGenres);
    _selectedType = widget.initialType;
    _selectedStatus = widget.initialStatus;
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final genresFuture = _apiService.getAllGenres();
      final typesFuture = _apiService.getAllTypes();

      final results = await Future.wait([genresFuture, typesFuture]);
      if (mounted) {
        setState(() {
          _allGenres = results[0];
          _allTypes = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load filter options: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedGenres.clear();
      _selectedType = null;
      _selectedStatus = null;
      _genreSearchQuery = '';
    });
  }

  int get _activeFilterCount =>
      (_selectedStatus != null ? 1 : 0) +
      (_selectedType != null ? 1 : 0) +
      _selectedGenres.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Filter Similar Manga',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_activeFilterCount > 0)
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _error = null;
                                });
                                _loadFilters();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        // Status section
                        _buildSectionHeader('Status', Icons.flag_outlined),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: 'All',
                              isSelected: _selectedStatus == null,
                              onSelected: () =>
                                  setState(() => _selectedStatus = null),
                            ),
                            ..._statuses.map((status) {
                              return _buildChoiceChip(
                                label: status,
                                isSelected: _selectedStatus == status,
                                onSelected: () => setState(() {
                                  _selectedStatus =
                                      _selectedStatus == status ? null : status;
                                }),
                              );
                            }),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Type section
                        _buildSectionHeader('Type', Icons.category_outlined),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChoiceChip(
                              label: 'All',
                              isSelected: _selectedType == null,
                              onSelected: () =>
                                  setState(() => _selectedType = null),
                            ),
                            ..._allTypes.map((type) {
                              return _buildChoiceChip(
                                label: type,
                                isSelected: _selectedType == type,
                                onSelected: () => setState(() {
                                  _selectedType =
                                      _selectedType == type ? null : type;
                                }),
                              );
                            }),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Manga's current genres (Quick Picks)
                        if (widget.mangaGenres.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Current Manga Genres',
                            Icons.auto_awesome_outlined,
                            subtitle: 'Tap to match these genres',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.mangaGenres.map((genre) {
                              final isSelected =
                                  _selectedGenres.contains(genre);
                              return FilterChip(
                                label: Text(genre),
                                selected: isSelected,
                                selectedColor:
                                    primaryColor.withValues(alpha: 0.25),
                                checkmarkColor: primaryColor,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                                backgroundColor: isDark
                                    ? AppColors.slate800
                                    : AppColors.slate100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.transparent,
                                  ),
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedGenres.add(genre);
                                    } else {
                                      _selectedGenres.remove(genre);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // All Genres Section with search
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionHeader(
                              'All Genres',
                              Icons.style_outlined,
                              subtitle: '${_selectedGenres.length} selected',
                            ),
                            if (_selectedGenres.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selectedGenres.clear()),
                                child: Text(
                                  'Clear Genres',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Search field for genres
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.slate800
                                : AppColors.slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search genres...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.withValues(alpha: 0.8),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _genreSearchQuery =
                                          val.trim().toLowerCase();
                                    });
                                  },
                                ),
                              ),
                              if (_genreSearchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _genreSearchQuery = ''),
                                  child: const Icon(Icons.clear,
                                      size: 16, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Genre chips
                        _buildGenreChips(isDark, primaryColor),
                      ],
                    ),
        ),

        // Bottom Action Bar
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.slate900 : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_activeFilterCount > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color:
                            isDark ? AppColors.slate700 : AppColors.slate300,
                      ),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (_activeFilterCount > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _selectedGenres,
                      _selectedType,
                      _selectedStatus,
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _activeFilterCount > 0
                        ? 'Apply Filters ($_activeFilterCount)'
                        : 'Apply Filters',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? AppColors.slate800 : AppColors.slate100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? AppColors.slate700 : AppColors.slate200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildGenreChips(bool isDark, Color primaryColor) {
    final filtered = _allGenres.where((g) {
      if (_genreSearchQuery.isEmpty) return true;
      return g.toLowerCase().contains(_genreSearchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No genres found matching "$_genreSearchQuery"',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered.map((genre) {
        final isSelected = _selectedGenres.contains(genre);
        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          selectedColor: primaryColor.withValues(alpha: 0.25),
          checkmarkColor: primaryColor,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white70 : Colors.black87),
          ),
          backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
            ),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedGenres.add(genre);
              } else {
                _selectedGenres.remove(genre);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
