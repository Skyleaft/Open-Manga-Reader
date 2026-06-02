import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../data/models/progression.dart';
import '../../../data/models/reader_content.dart';
import '../../../data/services/manga_api_service.dart';
import '../../../data/services/progression_service.dart';
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
    with TickerProviderStateMixin {
  final MangaApiService _apiService = getIt<MangaApiService>();
  final ProgressionService _progressionService = getIt<ProgressionService>();
  bool _showUI = true;
  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _isSliderScrolling = false;

  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.0;
  late Ticker _autoScrollTicker;
  Duration _lastTick = Duration.zero;

  final TransformationController _transformationController =
      TransformationController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;

  // Local state to allow chapter switching
  late List<String> _pageUrls;
  // _chapterTitle removed because it's unused
  late String _chapterId;
  late double _currentChapterNumber;

  double _progress = 0.0;
  int _currentPage = 1;
  TapDownDetails? _doubleTapDetails;

  // Reading time tracking
  int _initialReadingTimeSeconds = 0;
  late DateTime _sessionStartTime;

  bool _isWebtoonMode = true;
  bool _hideMiniProgressBar = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageUrls = widget.content.pageUrls;

    // _chapterTitle = widget.content.chapterTitle;
    _chapterId = widget.content.chapterId;
    _currentChapterNumber = widget.content.currentChapterNumber;

    _animationController = AnimationController(vsync: this);
    _autoScrollTicker = createTicker(_onAutoScrollTick);
    _pageController = PageController(
      initialPage:
          widget.content.currentPage > 1 &&
              widget.content.currentPage <= _pageUrls.length
          ? widget.content.currentPage - 1
          : 0,
    );

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

    _sessionStartTime = DateTime.now();
    _loadInitialReadingTime();
  }

  Future<void> _loadInitialReadingTime() async {
    try {
      final progression = await _progressionService.getProgression(
        widget.content.mangaId,
      );
      if (progression != null && mounted) {
        setState(() {
          _initialReadingTimeSeconds = progression.readingTimeSeconds;
        });
      }
    } catch (e) {
      debugPrint('Failed to load initial reading time: $e');
    }
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
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

    // Swipe up / overscroll to next chapter in Webtoon mode
    if (position.pixels >= maxScroll + 80 && !_isLoading) {
      _changeChapter(true);
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
      if (_pageController.hasClients && _currentPage > _pageUrls.length) {
        _pageController.animateToPage(
          _pageUrls.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final targetChapter = chapters[targetIndex];

    setState(() => _isLoading = true);

    try {
      final pages = await _apiService.getChapterPages(
        widget.content.mangaId,
        targetChapter.chapterNumber,
      );

      // Clear live images to allow eviction of previous chapter images
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Update total reading time before switching
      final sessionSeconds = DateTime.now()
          .difference(_sessionStartTime)
          .inSeconds;
      _initialReadingTimeSeconds += sessionSeconds;
      _sessionStartTime = DateTime.now();

      setState(() {
        _pageUrls = pages
            .map(
              (p) => _apiService.getLocalImageUrl(
                p['localImageUrl'] as String?,
                p['imageUrl'] as String?,
              ),
            )
            .toList();

        // _chapterTitle = targetChapter.title;
        _chapterId = targetChapter.id;
        _currentChapterNumber = targetChapter.chapterNumber;
        _progress = 0.0;
        _currentPage = 1;
        _isLoading = false;
        // Reset scroll position
        _transformationController.value = Matrix4.identity();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
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

  void _onAutoScrollTick(Duration elapsed) {
    if (!_isAutoScrolling) return;

    if (_isWebtoonMode) {
      if (!_scrollController.hasClients) return;

      final delta = elapsed - _lastTick;
      _lastTick = elapsed;

      final offset = _scrollController.offset;
      final maxScroll = _scrollController.position.maxScrollExtent;

      if (offset >= maxScroll) {
        _toggleAutoScroll();
        return;
      }

      final pixelsToMove =
          (delta.inMilliseconds / 1000) * 50 * _autoScrollSpeed;
      _scrollController.jumpTo(offset + pixelsToMove);
    } else {
      if (!_pageController.hasClients) return;

      final delta = elapsed - _lastTick;
      final pageFlipDuration = Duration(
        milliseconds: (8000 / _autoScrollSpeed).round(),
      );

      if (delta >= pageFlipDuration) {
        _lastTick = elapsed;
        if (_currentPage < _pageUrls.length) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } else {
          _toggleAutoScroll();
        }
      }
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
      if (_isAutoScrolling) {
        _lastTick = Duration.zero;
        _autoScrollTicker.start();
        _showUI = false;
      } else {
        _autoScrollTicker.stop();
      }
    });
  }

  void _changeAutoScrollSpeed() {
    setState(() {
      if (_autoScrollSpeed >= 3.0) {
        _autoScrollSpeed = 0.5;
      } else {
        _autoScrollSpeed += 0.5;
      }
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
        // ignore: deprecated_member_use
        ..translate(x, y, 0.0)
        // ignore: deprecated_member_use
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
    if (_isWebtoonMode) {
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
    } else {
      if (!_pageController.hasClients) return;
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.pageDown) {
        if (_currentPage < _pageUrls.length) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _changeChapter(true);
        }
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.pageUp) {
        if (_currentPage > 1) {
          _pageController.animateToPage(
            _currentPage - 2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _changeChapter(false);
        }
      }
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

  void _onPageChanged(int index) {
    if (_pageUrls.isEmpty) return;

    if (index == _pageUrls.length) {
      // Swiped past the last page! Load next chapter.
      _changeChapter(true);
      return;
    }

    final page = index + 1;
    final progress = (index / (_pageUrls.length - 1)).clamp(0.0, 1.0);
    setState(() {
      _currentPage = page;
      _progress = progress;
    });
    _debounceSaveProgression();
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const Text(
                          'Reading Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Reading Mode
                        _buildSettingRow(
                          icon: Icons.chrome_reader_mode_outlined,
                          title: 'Reading Mode',
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildModeSegment(
                                  label: 'Webtoon',
                                  isSelected: _isWebtoonMode,
                                  onTap: () {
                                    setSheetState(() => _isWebtoonMode = true);
                                    setState(() {
                                      _isWebtoonMode = true;
                                    });
                                  },
                                ),
                                _buildModeSegment(
                                  label: 'Manga',
                                  isSelected: !_isWebtoonMode,
                                  onTap: () {
                                    setSheetState(() => _isWebtoonMode = false);
                                    setState(() {
                                      _isWebtoonMode = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Auto Scroll
                        _buildSettingRow(
                          icon: Icons.play_arrow_outlined,
                          title: 'Auto Scroll',
                          trailing: Switch.adaptive(
                            value: _isAutoScrolling,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              _toggleAutoScroll();
                              if (val) {
                                Navigator.pop(context);
                              } else {
                                setSheetState(() {});
                              }
                            },
                          ),
                        ),
                        if (_isAutoScrolling) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.speed,
                                color: Colors.white38,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Speed',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _autoScrollSpeed,
                                  min: 0.5,
                                  max: 3.0,
                                  divisions: 5,
                                  activeColor: AppColors.primary,
                                  inactiveColor: Colors.white10,
                                  label: '${_autoScrollSpeed}x',
                                  onChanged: (val) {
                                    setSheetState(() => _autoScrollSpeed = val);
                                    setState(() {
                                      _autoScrollSpeed = val;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                '${_autoScrollSpeed}x',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Hide mini progress bar
                        _buildSettingRow(
                          icon: Icons.linear_scale,
                          title: 'Hide Mini Progress Bar',
                          trailing: Switch.adaptive(
                            value: _hideMiniProgressBar,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setSheetState(() => _hideMiniProgressBar = val);
                              setState(() {
                                _hideMiniProgressBar = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }

  Widget _buildModeSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxChapter = widget.content.allChapters.fold(
      0.0,
      (max, c) => c.chapterNumber > max ? c.chapterNumber : max,
    );
    final String maxChapterStr = maxChapter % 1 == 0
        ? maxChapter.toInt().toString()
        : maxChapter.toString();
    final String currentChapterStr = _currentChapterNumber % 1 == 0
        ? _currentChapterNumber.toInt().toString()
        : _currentChapterNumber.toString();

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
              pageController: _pageController,
              isWebtoonMode: _isWebtoonMode,
              onPageChanged: _onPageChanged,
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
                chapterTitle: 'Chapter $currentChapterStr / $maxChapterStr',
                onBack: () => Navigator.pop(context),
                onSettings: _showSettingsBottomSheet,
              ),
            ),

            // Bottom Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _showUI ? 20 : -350,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              ((value * (_pageUrls.length - 1)).round() + 1)
                                  .clamp(1, _pageUrls.length);
                        });

                        if (_scrollController.hasClients) {
                          final maxScroll =
                              _scrollController.position.maxScrollExtent;
                          final target = value * maxScroll;

                          if (maxScroll > 0) {
                            _scrollController.jumpTo(
                              target.clamp(0, maxScroll),
                            );
                          }
                        }

                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(_currentPage - 1);
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
                ),
              ),
            ),

            // Mini Progress Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showUI || _hideMiniProgressBar ? 0 : 1,
                      child: _pageUrls.isEmpty
                          ? const SizedBox.shrink()
                          : Row(
                              children: List.generate(_pageUrls.length, (
                                index,
                              ) {
                                final pageNumber = index + 1;
                                final isRead = pageNumber <= _currentPage;
                                return Expanded(
                                  child: Container(
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? AppColors.primary
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                );
                              }),
                            ),
                    ),
                  ),
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

    final sessionSeconds = DateTime.now()
        .difference(_sessionStartTime)
        .inSeconds;
    final totalReadingTime = _initialReadingTimeSeconds + sessionSeconds;

    final progression = MangaProgression(
      mangaId: widget.content.mangaId,
      chapterId: _chapterId,
      currentChapter: _currentChapterNumber,
      currentPage: _currentPage,
      totalPages: _pageUrls.length,
      lastRead: DateTime.now(),
      isCompleted: isCompleted,
      readingTimeSeconds: totalReadingTime,
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
