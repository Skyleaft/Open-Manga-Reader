import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../history/models/progression.dart';
import '../../models/manga_detail.dart';
import 'status_selection_sheet.dart';

class MangaDetailFloatingDock extends StatelessWidget {
  final List<Chapter> chapters;
  final Chapter? targetChapter;
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

  const MangaDetailFloatingDock({
    super.key,
    required this.chapters,
    this.targetChapter,
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

  Chapter? _getTargetChapter() {
    if (chapters.isEmpty) return null;
    final available = chapters.where((c) => c.isChapterAvailable).toList();
    if (available.isEmpty) return null;

    if (progression != null && progression!.currentChapter > 0) {
      final current = available
          .where((c) => c.chapterNumber == progression!.currentChapter)
          .firstOrNull;
      if (current != null) return current;
    }

    // Default to first available chapter (lowest number)
    return available.reduce((a, b) => a.chapterNumber < b.chapterNumber ? a : b);
  }

  String _getButtonLabel(Chapter? chapter) {
    if (isLoadingChapters) return 'Loading...';
    if (chapter == null) return 'No Chapters';

    final chNumStr = chapter.chapterNumber % 1 == 0
        ? chapter.chapterNumber.toInt().toString()
        : chapter.chapterNumber.toString();

    if (progression != null && progression!.currentChapter > 0) {
      if (progression!.currentPage > 0) {
        return 'Continue Ch. $chNumStr (P. ${progression!.currentPage})';
      }
      return 'Continue Ch. $chNumStr';
    }
    return 'Start Ch. $chNumStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final activeTarget = targetChapter ?? _getTargetChapter();
    final buttonLabel = _getButtonLabel(activeTarget);

    final Color dockBgColor = isDark
        ? const Color(0xF20F172A)
        : const Color(0xF8FFFFFF);
    final Color dockBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: dockBgColor,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: dockBorderColor, width: 1),
                ),
                child: Row(
                      children: [
                        // Main Action: Big Pill Button (Continue / Start Reading)
                        Expanded(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.85),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isLoadingChapters || activeTarget == null
                                    ? null
                                    : () {
                                        AppHaptics.mediumImpact();
                                        onReadChapter(activeTarget);
                                      },
                                borderRadius: BorderRadius.circular(28),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        progression != null && progression!.currentChapter > 0
                                            ? Icons.play_arrow_rounded
                                            : Icons.auto_stories_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          buttonLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Library Button
                        _buildLibraryButton(context, isDark, colorScheme),

                        const SizedBox(width: 6),

                        // Favorite Button
                        _buildFavoriteButton(context, isDark, colorScheme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildLibraryButton(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final hasStatus = isInLibrary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          AppHaptics.selection();
          if (hasStatus) {
            _showLibraryOptionsSheet(context, isDark, colorScheme);
          } else {
            final selected = await StatusSelectionSheet.show(context);
            if (selected != null) {
              onAddToLibrary(selected);
            }
          }
        },
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasStatus
                ? colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
            border: Border.all(
              color: hasStatus
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08)),
              width: 1,
            ),
          ),
          child: Icon(
            hasStatus ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: hasStatus
                ? (libraryStatus != null
                    ? StatusSelectionSheet.getColor(libraryStatus!)
                    : colorScheme.primary)
                : (isDark ? Colors.white70 : Colors.black87),
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showLibraryOptionsSheet(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final currentLabel = libraryStatus != null
        ? StatusSelectionSheet.getLabel(libraryStatus!)
        : 'In Library';
    final currentColor = libraryStatus != null
        ? StatusSelectionSheet.getColor(libraryStatus!)
        : colorScheme.primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Library Status: $currentLabel',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colorScheme.primary),
              title: const Text('Change Reading Status'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.pop(ctx);
                final newStatus = await StatusSelectionSheet.show(
                  context,
                  currentStatus: libraryStatus,
                );
                if (newStatus != null) {
                  onChangeLibraryStatus?.call(newStatus);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined, color: Colors.redAccent),
              title: const Text(
                'Remove from Library',
                style: TextStyle(color: Colors.redAccent),
              ),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(ctx);
                onRemoveFromLibrary();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return FavoriteButton(
      isFavorite: isFavorite,
      onTap: onToggleFavorite,
      isDark: isDark,
    );
  }
}

class FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final bool isDark;

  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    // Subtle whole-button compression and spring release
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_controller);

    // Heart icon energetic bounce and pop
    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite && !_controller.isAnimating) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final nextState = !widget.isFavorite;
    AppHaptics.favorite(nextState);

    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    const favoriteColor = Color(0xFFEF4444);
    final isFav = widget.isFavorite;

    return Tooltip(
      message: isFav ? 'Remove from favorites' : 'Add to favorites',
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(25),
            splashColor: favoriteColor.withValues(alpha: 0.2),
            highlightColor: favoriteColor.withValues(alpha: 0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFav
                    ? favoriteColor.withValues(alpha: widget.isDark ? 0.22 : 0.15)
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                border: Border.all(
                  color: isFav
                      ? favoriteColor.withValues(alpha: 0.45)
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: 1,
                ),
                boxShadow: isFav
                    ? [
                        BoxShadow(
                          color: favoriteColor.withValues(alpha: widget.isDark ? 0.28 : 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: ScaleTransition(
                  scale: _iconScaleAnimation,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey<bool>(isFav),
                      color: isFav
                          ? favoriteColor
                          : (widget.isDark ? Colors.white70 : Colors.black87),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
