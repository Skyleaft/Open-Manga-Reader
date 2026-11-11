import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../history/models/progression.dart';
import '../../models/manga_detail.dart';
import 'status_selection_sheet.dart';

class MangaDetailActionBar extends StatelessWidget {
  final List<Chapter> chapters;
  final bool isLoadingChapters;
  final bool isInLibrary;
  final bool isFavorite;
  final String? libraryStatus;
  final MangaProgression? progression;
  final ValueChanged<Chapter> onReadChapter;
  final ValueChanged<String> onAddToLibrary;
  final ValueChanged<String>? onChangeLibraryStatus;
  final VoidCallback onRemoveFromLibrary;
  final VoidCallback onToggleFavorite;

  const MangaDetailActionBar({
    super.key,
    required this.chapters,
    required this.isLoadingChapters,
    required this.isInLibrary,
    required this.isFavorite,
    this.libraryStatus,
    required this.progression,
    required this.onReadChapter,
    required this.onAddToLibrary,
    this.onChangeLibraryStatus,
    required this.onRemoveFromLibrary,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (progression != null) {
      return _buildResumeActionButtons(context, progression!);
    }
    return _buildDefaultActionButtons(context);
  }

  Widget _buildDefaultActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final availableChapters =
        chapters.where((c) => c.isChapterAvailable).toList();
    final firstChapter =
        availableChapters.isNotEmpty ? availableChapters.last : null;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                if (!isLoadingChapters && firstChapter != null)
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: isLoadingChapters || firstChapter == null
                  ? null
                  : () => onReadChapter(firstChapter),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 20),
              label: Text(
                'Start Chapter 1',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildLibraryButton(context, isDark, colorScheme),
        if (isInLibrary) ...[
          const SizedBox(width: 10),
          _buildFavoriteButton(context, isDark),
        ],
      ],
    );
  }

  Widget _buildResumeActionButtons(
    BuildContext context,
    MangaProgression currentProgression,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Find exact or next uncompleted chapter
    Chapter? targetChapter;
    for (final c in chapters) {
      if (c.chapterNumber == currentProgression.currentChapter) {
        targetChapter = c;
        break;
      }
    }

    targetChapter ??= chapters.isNotEmpty ? chapters.last : null;

    final String numStr = targetChapter != null
        ? (targetChapter.chapterNumber % 1 == 0
            ? targetChapter.chapterNumber.toInt().toString()
            : targetChapter.chapterNumber.toString())
        : (currentProgression.currentChapter % 1 == 0
            ? currentProgression.currentChapter.toInt().toString()
            : currentProgression.currentChapter.toString());

    final buttonText =
        'Resume Ch. $numStr (Pg. ${currentProgression.currentPage})';

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: targetChapter != null
                  ? () => onReadChapter(targetChapter!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                buttonText,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildLibraryButton(context, isDark, colorScheme),
        if (isInLibrary) ...[
          const SizedBox(width: 10),
          _buildFavoriteButton(context, isDark),
        ],
      ],
    );
  }

  Widget _buildLibraryButton(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isInLibrary
            ? colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
            : (isDark
                ? const Color(0xFF1E293B)
                : Colors.black.withValues(alpha: 0.05)),
        shape: BoxShape.circle,
        border: Border.all(
          color: isInLibrary
              ? colorScheme.primary.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1,
        ),
      ),
      child: IconButton(
        tooltip: isInLibrary
            ? 'In Library (${libraryStatus != null ? StatusSelectionSheet.getLabel(libraryStatus!) : ''})'
            : 'Add to Library',
        icon: Icon(
          isInLibrary ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          color: isInLibrary
              ? (libraryStatus != null
                  ? StatusSelectionSheet.getColor(libraryStatus!)
                  : colorScheme.primary)
              : (isDark ? Colors.white70 : Colors.black54),
        ),
        onPressed: () async {
          AppHaptics.selection();
          if (isInLibrary) {
            _showLibraryOptionsSheet(context, isDark);
          } else {
            final selected = await StatusSelectionSheet.show(context);
            if (selected != null) {
              onAddToLibrary(selected);
            }
          }
        },
      ),
    );
  }

  void _showLibraryOptionsSheet(BuildContext context, bool isDark) {
    final currentLabel = libraryStatus != null
        ? StatusSelectionSheet.getLabel(libraryStatus!)
        : 'In Library';
    final currentColor = libraryStatus != null
        ? StatusSelectionSheet.getColor(libraryStatus!)
        : Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bookmark_rounded, color: currentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Library Status',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Current: $currentLabel',
                          style: TextStyle(
                            fontSize: 13,
                            color: currentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 20),
                ),
                title: const Text('Change Reading Status', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Update to Plan to Read, Completed, etc.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(context);
                  final selected = await StatusSelectionSheet.show(
                    context,
                    currentStatus: libraryStatus,
                  );
                  if (selected != null && selected != libraryStatus) {
                    onChangeLibraryStatus?.call(selected);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                ),
                title: const Text('Remove from Library', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                subtitle: const Text('Remove this manga from your collection'),
                onTap: () {
                  Navigator.pop(context);
                  onRemoveFromLibrary();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteButton(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isFavorite
            ? Colors.red.withValues(alpha: isDark ? 0.22 : 0.14)
            : (isDark
                ? const Color(0xFF1E293B)
                : Colors.black.withValues(alpha: 0.05)),
        shape: BoxShape.circle,
        border: Border.all(
          color: isFavorite
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1,
        ),
      ),
      child: IconButton(
        tooltip: isFavorite ? 'Favorited' : 'Add to Favorites',
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite
              ? Colors.redAccent
              : (isDark ? Colors.white70 : Colors.black54),
        ),
        onPressed: () {
          AppHaptics.favorite(!isFavorite);
          onToggleFavorite();
        },
      ),
    );
  }
}
