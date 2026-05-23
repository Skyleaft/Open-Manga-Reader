import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/manga_card.dart';
import '../../../data/models/library_manga.dart';
import '../../../data/models/manga_detail.dart';
import '../../../data/services/library_service.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/manga_detail_service.dart';
import '../../../routes/app_pages.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final LibraryService _libraryService = getIt<LibraryService>();
  final MangaApiService _apiService = getIt<MangaApiService>();
  final MangaDetailService _detailService = getIt<MangaDetailService>();
  List<LibraryManga> _libraryMangas = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    try {
      final libraryMangas = await _libraryService.getAllLibraryMangas();
      if (mounted) {
        setState(() {
          _libraryMangas = libraryMangas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    // Force a fresh API fetch then reload from the updated local cache
    final apiService = getIt<MangaApiService>();
    try {
      await apiService.getUserLibrary();
      await apiService.getUserProgression();
    } catch (_) {}
    await _loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor:
                  (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                      .withOpacity(0.8),
              surfaceTintColor: Colors.transparent,
              expandedHeight: 220,
              toolbarHeight: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: _buildHeader(context, isDark),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              sliver: _buildContent(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.history);
                },
                icon: const Icon(Icons.history_outlined),
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search in library',
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
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

  Widget _buildFilterChip(String label) {
    final bool isActive = _selectedStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : Colors.grey[200]!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final filteredMangas = _libraryMangas.where((m) {
      final matchesStatus = _selectedStatus == 'All' ||
          m.status.toLowerCase() == _selectedStatus.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          m.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredMangas.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              _selectedStatus == 'All'
                  ? 'Your library is empty\nAdd some manga to get started!'
                  : 'No manga with status $_selectedStatus',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 12,
        childAspectRatio: 0.6,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final manga = filteredMangas[index];
        return MangaCard(
          title: manga.title,
          imageUrl: manga.imageUrl,
          localImageUrl: manga.imageUrl,
          currentChapter: manga.currentChapter.toInt(),
          totalChapters: 0, // Library manga doesn't track total chapters
          progress: manga.progressPercentage,
          isCompleted: manga.isCompleted,
          type: manga.type, // Use the type from library manga
          status: manga.status,
          genres: [], // Library doesn't track genres
          onTap: () async {
            final mangaId = manga.id;

            // 1. Try local cache first (instant, works offline)
            final cached = await _detailService.getDetail(mangaId);

            if (cached != null && mounted) {
              // Navigate immediately with cached data
              Navigator.pushNamed(
                context,
                AppRoutes.detail,
                arguments: cached,
              );
              // 2. Background sync: fetch latest from API and update cache
              _apiService.getMangaDetail(mangaId).then((data) {
                final fresh = MangaDetail.fromMap(data);
                _detailService.saveDetail(fresh);
              }).catchError((_) {});
              return;
            }

            // 3. No cache — fetch from API with a loading indicator
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              final detailData = await _apiService.getMangaDetail(mangaId);
              if (!mounted) return;
              Navigator.pop(context); // Close loading dialog

              final mangaDetail = MangaDetail.fromMap(detailData);
              // Save to local cache for future offline access
              await _detailService.saveDetail(mangaDetail);

              Navigator.pushNamed(
                context,
                AppRoutes.detail,
                arguments: mangaDetail,
              );
            } catch (e) {
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to load details: $e')),
              );
            }
          },
        );
      }, childCount: filteredMangas.length),
    );
  }
}
