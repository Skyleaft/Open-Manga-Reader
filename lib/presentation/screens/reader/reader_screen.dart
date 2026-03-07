import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../data/models/progression.dart';
import '../../../data/models/reader_content.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/progression_service.dart';
import 'widgets/app_network_image.dart';
import 'widgets/reader_header.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_content.dart';

class ReaderScreen extends StatefulWidget {
  final ReaderContent content;

  const ReaderScreen({super.key, required this.content});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final ProgressionService _progressionService = getIt<ProgressionService>();
  bool _showUI = true;
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _isSliderScrolling = false;

  final TransformationController _transformationController =
      TransformationController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  // Local state to allow chapter switching
  late List<String> _pageUrls;
  late String _chapterTitle;
  late double _currentChapterNumber;

  double _progress = 0.0;
  int _currentPage = 1;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _pageUrls = widget.content.pageUrls;

    _chapterTitle = widget.content.chapterTitle;
    _currentChapterNumber = widget.content.currentChapterNumber;

    _animationController = AnimationController(vsync: this);

    // Set initial scroll position based on saved progress
    if (widget.content.currentPage > 1 &&
        widget.content.currentPage <= _pageUrls.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetScroll =
              ((widget.content.currentPage - 1) / (_pageUrls.length - 1)) *
              maxScroll;
          _scrollController.jumpTo(targetScroll);

          // Update progress and page state to match the scroll position
          setState(() {
            _progress = (targetScroll / maxScroll).clamp(0.0, 1.0);
            _currentPage = widget.content.currentPage;
          });
        }
      });
    }

    _transformationController.addListener(_onTransformationChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    // Update UI state when transformation changes
    setState(() {});
  }

  void _onScroll() {
    if (_isSliderScrolling) return;
    if (!_scrollController.hasClients) return;
    if (_pageUrls.isEmpty) return;

    final position = _scrollController.position;

    if (!position.hasContentDimensions) return;

    final maxScroll = position.maxScrollExtent;

    if (maxScroll <= 0) return;

    final currentScroll = position.pixels.clamp(0.0, maxScroll);

    final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);

    final page = ((progress * (_pageUrls.length - 1)).round() + 1).clamp(
      1,
      _pageUrls.length,
    );

    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
        _progress = progress;
      });

      _debounceSaveProgression();
    }
  }

  void _debounceSaveProgression() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () {
      _saveProgression();
    });
  }

  Future<void> _changeChapter(bool next) async {
    final chapters = widget.content.allChapters;
    // Chapters are usually sorted DESC (latest first)
    final currentIndex = chapters.indexWhere(
      (c) => c.chapterNumber == _currentChapterNumber,
    );

    int targetIndex;
    if (next) {
      // If DESC, next is lower index (e.g. current is chapter 5 at index 10, next is chapter 6 at index 9)
      targetIndex = currentIndex - 1;
    } else {
      targetIndex = currentIndex + 1;
    }

    if (targetIndex < 0 || targetIndex >= chapters.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'This is the latest chapter' : 'This is the first chapter',
          ),
        ),
      );
      return;
    }

    final targetChapter = chapters[targetIndex];

    setState(() => _isLoading = true);

    try {
      final pages = await _apiService.getChapterPages(
        widget.content.mangaId,
        targetChapter.chapterNumber,
      );

      setState(() {
        _pageUrls = pages
            .map(
              (p) => _apiService.getLocalImageUrl(
                p['localImageUrl'] as String?,
                p['imageUrl'] as String?,
              ),
            )
            .toList();

        _chapterTitle = targetChapter.title;
        _currentChapterNumber = targetChapter.chapterNumber;
        _progress = 0.0;
        _currentPage = 1;
        _isLoading = false;
        // Reset scroll position
        _transformationController.value = Matrix4.identity();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load chapter: $e')));
      }
    }
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale > 1.0) {
      // Zoom out with animation
      _animateTo(
        Matrix4.identity(),
        duration: const Duration(milliseconds: 250),
      );
    } else if (_doubleTapDetails != null) {
      // Zoom in with animation
      final position = _doubleTapDetails!.localPosition;
      const targetScale = 2.5;

      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);

      final targetMatrix = Matrix4.identity()
        ..translate(x, y, 0.0)
        ..scale(targetScale, targetScale, 1.0);

      _animateTo(targetMatrix, duration: const Duration(milliseconds: 250));
    }
  }

  void _animateTo(Matrix4 targetMatrix, {required Duration duration}) {
    // Cancel any ongoing animation
    _animationController.stop();
    _animationController.reset();

    // Set up the animation
    _animationController.duration = duration;

    final currentMatrix = _transformationController.value;
    final animation = Matrix4Tween(begin: currentMatrix, end: targetMatrix)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    animation.addListener(() {
      _transformationController.value = animation.value;
    });

    _animationController.forward();
  }

  void _handleKeyboard(LogicalKeyboardKey key) {
    if (!_scrollController.hasClients) return;

    final double scrollAmount = 200.0; // Jarak scroll arrow keys
    final double pageAmount =
        MediaQuery.of(context).size.height * 0.8; // Jarak PageUp/Down
    final double currentOffset = _scrollController.offset;

    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollSmoothly(currentOffset + scrollAmount);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _scrollSmoothly(currentOffset - scrollAmount);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollSmoothly(currentOffset + pageAmount);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollSmoothly(currentOffset - pageAmount);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _changeChapter(true); // Next Chapter
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _changeChapter(false); // Previous Chapter
    }
  }

  void _scrollSmoothly(double target) {
    final max = _scrollController.position.maxScrollExtent;
    final min = _scrollController.position.minScrollExtent;

    _scrollController.animateTo(
      target.clamp(min, max),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Gunakan Focus agar bisa menangkap event keyboard
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          _handleKeyboard(event.logicalKey);
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Content Area
            ReaderContentWidget(
              pageUrls: _pageUrls,
              isLoading: _isLoading,
              showUI: _showUI,
              transformationController: _transformationController,
              scrollController: _scrollController,
              onTap: _toggleUI,
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              onToggleUI: _toggleUI,
            ),

            // Top Header
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _showUI ? 0 : -150,
              left: 0,
              right: 0,
              child: ReaderHeader(
                mangaTitle: widget.content.mangaTitle,
                chapterTitle: _chapterTitle,
                onBack: () => Navigator.pop(context),
                onSettings: () {},
              ),
            ),

            // Bottom Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _showUI ? 20 : -350,
              left: 20,
              right: 20,
              child: ReaderBottomBar(
                progress: _progress,
                currentPage: _currentPage,
                totalPages: _pageUrls.length,
                isSliderScrolling: _isSliderScrolling,
                onProgressChanged: (value) {
                  setState(() {
                    _progress = value;
                    if (_pageUrls.isEmpty) return;

                    _currentPage =
                        ((value * (_pageUrls.length - 1)).round() + 1).clamp(
                          1,
                          _pageUrls.length,
                        );
                  });

                  if (_scrollController.hasClients) {
                    final maxScroll =
                        _scrollController.position.maxScrollExtent;
                    final target = value * maxScroll;

                    if (maxScroll > 0) {
                      _scrollController.jumpTo(target.clamp(0, maxScroll));
                    }
                  }
                },
                onProgressChangeStart: (_) {
                  _isSliderScrolling = true;
                },
                onProgressChangeEnd: (_) {
                  _isSliderScrolling = false;
                },
                onNextChapter: () => _changeChapter(true),
                onPreviousChapter: () => _changeChapter(false),
              ),
            ),

            // Mini Progress Bar
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showUI ? 0 : 1,
                child: LinearProgressIndicator(
                  value: _progress,
                  borderRadius: BorderRadius.circular(16),
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProgression() async {
    final isCompleted = _progress >= 0.99;

    final progression = MangaProgression(
      mangaId: widget.content.mangaId,
      currentChapter: _currentChapterNumber,
      currentPage: _currentPage,
      totalPages: _pageUrls.length,
      lastRead: DateTime.now(),
      isCompleted: isCompleted,
    );

    try {
      await _progressionService.saveProgression(progression);
    } catch (e) {
      // Show error message to help debug the issue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Log the error for debugging
      debugPrint('Progression save error: $e');
    }
  }
}
