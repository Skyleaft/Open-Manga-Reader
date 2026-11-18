import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/manga_summary.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../../manga_detail/models/manga_detail.dart';
import '../../models/search_result.dart';

class ScrapMangaModal extends StatefulWidget {
  final SearchResult item;
  final String provider;
  final MangaApiService apiService;
  final Function(bool scrapChapters, String? linkId) onScrap;

  const ScrapMangaModal({
    super.key,
    required this.item,
    required this.provider,
    required this.apiService,
    required this.onScrap,
  });

  @override
  State<ScrapMangaModal> createState() => _ScrapMangaModalState();
}

class _ScrapMangaModalState extends State<ScrapMangaModal> {
  bool _isLoadingDetail = true;
  MangaDetail? _detail;
  String? _error;

  bool _isSearchingExisting = false;
  List<MangaSummary> _existingMangaResults = [];
  MangaSummary? _selectedExistingManga;
  final _existingSearchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _existingSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoadingDetail = true;
      _error = null;
    });

    try {
      final data = await widget.apiService.getScrapMangaDetail(
        provider: widget.provider,
        mangaUrl: widget.item.detailUrl,
      );
      if (mounted) {
        setState(() {
          _detail = MangaDetail.fromMap(data);
          _isLoadingDetail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingDetail = false;
        });
      }
    }
  }

  void _searchExistingManga(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _existingMangaResults = [];
        _isSearchingExisting = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearchingExisting = true);
      try {
        final response = await widget.apiService.getPagedManga(
          search: query.trim(),
          pageSize: 10,
        );
        if (mounted) {
          setState(() {
            _existingMangaResults = response.items;
            _isSearchingExisting = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSearchingExisting = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.primary;

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(16.0),
      child: _isLoadingDetail
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : _error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load manga details: $_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchDetail,
                  child: const Text('Retry'),
                ),
              ],
            )
          : _buildDetailContent(isDark, textColor),
    );
  }

  Widget _buildDetailContent(bool isDark, Color textColor) {
    final detail = _detail!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.displayImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.apiService.getImageUrl(detail.displayImageUrl),
                    width: 90,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90,
                      height: 120,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Author: ${detail.author.isNotEmpty ? detail.author : "Unknown"}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type: ${detail.type} | Status: ${detail.status ?? "Unknown"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (detail.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            detail.rating!.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (detail.genres != null && detail.genres!.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: detail.genres!.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              detail.description!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Total Chapters: ${detail.chapters.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: detail.chapters.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No chapters found'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: detail.chapters.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ch = detail.chapters[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          ch.title,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          'Number: ${ch.chapterNumber}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: ch.language.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ch.language.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Text(
            'Link to Existing Manga (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (_selectedExistingManga == null) ...[
            TextField(
              controller: _existingSearchController,
              decoration: InputDecoration(
                hintText: 'Search local manga to link...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _isSearchingExisting
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: _searchExistingManga,
            ),
            if (_existingMangaResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _existingMangaResults.length,
                  itemBuilder: (context, index) {
                    final ex = _existingMangaResults[index];
                    return ListTile(
                      dense: true,
                      title: Text(ex.title),
                      subtitle: Text(ex.author),
                      onTap: () {
                        setState(() {
                          _selectedExistingManga = ex;
                          _existingMangaResults = [];
                          _existingSearchController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedExistingManga!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${_selectedExistingManga!.id}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedExistingManga = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScrap(false, _selectedExistingManga?.id);
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Scrap Metadata'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    foregroundColor: Colors.orange,
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onScrap(true, _selectedExistingManga?.id);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Scrap Chapters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
