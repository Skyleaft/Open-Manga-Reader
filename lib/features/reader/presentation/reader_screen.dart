import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../history/models/progression.dart';
import '../../history/services/progression_service.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../models/reader_content.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_chapter_picker_sheet.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_header.dart';
import 'widgets/reader_settings_sheet.dart';

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
  bool _isChangingChapter = false;
  DateTime _lastChapterChangeTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounceTimer;
  bool _isSliderScrolling = false;
  bool _isRestoringScroll = false;
  bool _isJumpingToPage = false;
  double _accumulatedBottomOverscroll = 0.0;
  double _targetProgress = 0.0;

  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 1.0;
  late Ticker _autoScrollTicker;
  Duration _lastTick = Duration.zero;

  final TransformationController _transformationController =
      TransformationController();
  late final ScrollController _scrollController;
  late AnimationController _animationController;
  late final PageController _pageController;

  late List<String> _pageUrls;
  late String _chapterId;
  late double _currentChapterNumber;

  final Map<int, double> _pageAspectRatios = {};
  final Map<int, GlobalKey> _pageKeys = {};
  double _progress = 0.0;
  int _currentPage = 1;
  TapDownDetails? _doubleTapDetails;

  int _chapterInitialReadingTimeSeconds = 0;
  late DateTime _sessionStartTime;

  bool _isWebtoonMode = true;
  bool _isRtlMode = false;
  bool _hideMiniProgressBar = false;
  bool _isFullscreen = false;
  CancelToken? _chapterCancelToken;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;
    _pageUrls = widget.content.pageUrls;
    _chapterId = widget.content.chapterId;
    _currentChapterNumber = widget.content.currentChapterNumber;
    if (widget.content.pageAspectRatios != null) {
      _pageAspectRatios.addAll(widget.content.pageAspectRatios!);
    }

    _animationController = AnimationController(vsync: this);
    _autoScrollTicker = createTicker(_onAutoScrollTick);
    _pageController = PageController(
      initialPage:
          widget.content.currentPage > 1 &&
              widget.content.currentPage <= _pageUrls.length
          ? widget.content.currentPage - 1
          : 0,
    );

    if (widget.content.currentPage > 1 &&
        widget.content.currentPage <= _pageUrls.length) {
      _isRestoringScroll = true;
      _currentPage = widget.content.currentPage;
      _targetProgress =
          (widget.content.currentPage - 1) / (_pageUrls.length - 1);
      _progress = _targetProgress;
    }

    _scrollController = ScrollController();

    if (widget.content.currentPage > 1 &&
        widget.content.currentPage <= _pageUrls.length) {
      _restoreInitialScroll();
    }

    _transformationController.addListener(_onTransformationChanged);
    _scrollController.addListener(_onScroll);

    _sessionStartTime = DateTime.now();
    _loadInitialReadingTime();
    _checkInitialFullscreen();
  }

  GlobalKey _getPageKey(int index) {
    return _pageKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'webtoon_page_$index'),
    );
  }

  double _calculateAverageRatio() {
    if (_pageAspectRatios.isNotEmpty) {
      final sum = _pageAspectRatios.values.fold(0.0, (a, b) => a + b);
      return sum / _pageAspectRatios.length;
    }
    return 1.4;
  }

  double _calculateEstimatedOffset(int targetIndex, double contentWidth) {
    if (targetIndex <= 0 || _pageUrls.isEmpty) return 0.0;

    // If target is the last page and scrollController is ready, target maxScrollExtent directly
    if (_scrollController.hasClients && targetIndex >= _pageUrls.length - 1) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) return maxScroll;
    }

    // If we have maxScrollExtent but aspect ratios are mostly unknown, use proportional estimate
    if (_scrollController.hasClients && _pageUrls.length > 1) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0 && _pageAspectRatios.length < (_pageUrls.length / 2)) {
        final progressRatio = targetIndex / (_pageUrls.length - 1);
        return progressRatio * maxScroll;
      }
    }

    final avgRatio = _calculateAverageRatio();
    double offset = 0.0;
    for (int i = 0; i < targetIndex; i++) {
      final ratio = _pageAspectRatios[i] ?? avgRatio;
      offset += contentWidth * ratio;
    }
    return offset;
  }

  int? _getClosestVisiblePageIndex() {
    int? bestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < _pageUrls.length; i++) {
      final key = _getPageKey(i);
      final ctx = key.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize && renderBox.attached) {
          final pos = renderBox.localToGlobal(Offset.zero);
          final distance = pos.dy.abs();
          if (distance < minDistance) {
            minDistance = distance;
            bestIndex = i;
          }
        }
      }
    }
    return bestIndex;
  }

  void _jumpToWebtoonPage(
    int targetIndex, {
    double? explicitOffset,
    int retryCount = 0,
  }) {
    _isJumpingToPage = true;
    _isRestoringScroll = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_isWebtoonMode) {
        _isJumpingToPage = false;
        _isRestoringScroll = false;
        return;
      }
      if (targetIndex < 0 || targetIndex >= _pageUrls.length) {
        _isJumpingToPage = false;
        _isRestoringScroll = false;
        return;
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final contentWidth = (screenWidth < 800.0 ? screenWidth : 800.0);
      final targetOffset =
          explicitOffset ??
          _calculateEstimatedOffset(targetIndex, contentWidth);

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final safeTarget = maxScroll > 0
            ? targetOffset.clamp(0.0, maxScroll)
            : targetOffset.clamp(0.0, double.infinity);
        _scrollController.jumpTo(safeTarget);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          _isJumpingToPage = false;
          _isRestoringScroll = false;
          return;
        }

        final targetKey = _getPageKey(targetIndex);
        final targetContext = targetKey.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.0,
            duration: Duration.zero,
          );

          setState(() {
            _currentPage = targetIndex + 1;
            _progress = _pageUrls.length > 1
                ? (targetIndex / (_pageUrls.length - 1)).clamp(0.0, 1.0)
                : 0.0;
            _isRestoringScroll = false;
          });
          _debounceSaveProgression();

          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isJumpingToPage = false;
              });
            }
          });
        } else if (retryCount < 4) {
          final visibleIndex = _getClosestVisiblePageIndex();
          if (visibleIndex != null && visibleIndex != targetIndex) {
            final avgRatio = _calculateAverageRatio();
            final deltaPages = targetIndex - visibleIndex;
            final currentOffset = _scrollController.offset;
            final correctedOffset =
                currentOffset + (deltaPages * contentWidth * avgRatio);

            _jumpToWebtoonPage(
              targetIndex,
              explicitOffset: correctedOffset,
              retryCount: retryCount + 1,
            );
          } else {
            if (targetIndex >= _pageUrls.length - 1 && _scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (maxScroll > 0) {
                _scrollController.jumpTo(maxScroll);
              }
            }
            setState(() {
              _isRestoringScroll = false;
            });
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isJumpingToPage = false;
                });
              }
            });
            _onScroll();
          }
        } else {
          if (targetIndex >= _pageUrls.length - 1 && _scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            if (maxScroll > 0) {
              _scrollController.jumpTo(maxScroll);
            }
          }
          setState(() {
            _isRestoringScroll = false;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isJumpingToPage = false;
              });
            }
          });
          _onScroll();
        }
      });
    });
  }

  void _restoreInitialScroll() {
    if (widget.content.currentPage <= 1 || _pageUrls.isEmpty) {
      _isRestoringScroll = false;
      return;
    }
    _jumpToWebtoonPage(widget.content.currentPage - 1);
  }

  Future<void> _checkInitialFullscreen() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final isFull = await windowManager.isFullScreen();
        if (mounted) setState(() => _isFullscreen = isFull);
      } catch (e) {
        debugPrint('Window manager full screen check error: $e');
      }
    }
  }

  Future<void> _loadInitialReadingTime({String? chapterId}) async {
    final targetChapterId = chapterId ?? _chapterId;
    try {
      final progression =
          widget.content.progression ??
          await _progressionService.getProgression(widget.content.mangaId);
      if (progression != null && mounted) {
        final chapterLog = progression.chapterLogs
            .where((l) => l.chapterId == targetChapterId)
            .fold<UserChapterLog?>(
              null,
              (prev, l) => prev == null || l.lastReadAt.isAfter(prev.lastReadAt)
                  ? l
                  : prev,
            );
        setState(() {
          _chapterInitialReadingTimeSeconds =
              chapterLog?.readingTimeSeconds ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Failed to load initial reading time: $e');
    }
  }

  @override
  void dispose() {
    _chapterCancelToken?.cancel();
    _autoScrollTicker.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTransformationChanged() {
    setState(() {});
  }

  void _onScroll() {
    if (_isSliderScrolling ||
        _isRestoringScroll ||
        _isJumpingToPage ||
        _isChangingChapter ||
        _isLoading) {
      return;
    }
    if (!_scrollController.hasClients) {
      return;
    }
    if (_pageUrls.isEmpty) {
      return;
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final maxScroll = position.maxScrollExtent;

    if (!_isWebtoonMode) {
      return;
    }

    int? activePage;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetYThreshold = screenHeight * 0.35;

    // 1. If at or near the bottom of the chapter, immediately set activePage to the last page
    if (maxScroll > 0 &&
        (position.pixels >= maxScroll - 80 || position.extentAfter <= 80)) {
      activePage = _pageUrls.length;
    } else {
      for (int i = 0; i < _pageUrls.length; i++) {
        final key = _getPageKey(i);
        final ctx = key.currentContext;
        if (ctx != null) {
          final renderBox = ctx.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize && renderBox.attached) {
            final pos = renderBox.localToGlobal(Offset.zero);
            final top = pos.dy;
            final bottom = top + renderBox.size.height;

            if (top <= targetYThreshold && bottom > 0) {
              activePage = i + 1;
              break;
            }
          }
        }
      }

      if (activePage == null && maxScroll > 0) {
        final currentScroll = position.pixels;
        final screenWidth = MediaQuery.of(context).size.width;
        final contentWidth = (screenWidth < 800.0 ? screenWidth : 800.0);
        final focalPoint = currentScroll + (screenHeight * 0.35);
        double cumulativeOffset = 0.0;
        for (int i = 0; i < _pageUrls.length; i++) {
          final ratio = _pageAspectRatios[i] ?? 1.4;
          final pageHeight = contentWidth * ratio;
          if (focalPoint < cumulativeOffset + pageHeight) {
            activePage = i + 1;
            break;
          }
          cumulativeOffset += pageHeight;
        }
        activePage ??= _pageUrls.length;
      }
    }

    if (activePage != null && activePage != _currentPage) {
      final newProgress = _pageUrls.length > 1
          ? ((activePage - 1) / (_pageUrls.length - 1)).clamp(0.0, 1.0)
          : 1.0;

      setState(() {
        _currentPage = activePage!;
        _progress = newProgress;
      });

      _debounceSaveProgression();
    }
  }

  void _debounceSaveProgression() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _saveProgression();
    });
  }

  Future<void> _changeChapter(bool next) async {
    if (_isChangingChapter || _isLoading) return;

    final now = DateTime.now();
    if (now.difference(_lastChapterChangeTime).inMilliseconds < 600) {
      return;
    }

    final targetChapter = next
        ? widget.content.getNextChapter(_chapterId, _currentChapterNumber)
        : widget.content.getPreviousChapter(_chapterId, _currentChapterNumber);

    if (targetChapter == null) {
      if (!mounted) return;
      AlertBanner.show(
        context,
        next ? 'This is the latest chapter' : 'This is the first chapter',
        type: AlertBannerType.info,
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

    _isChangingChapter = true;
    _accumulatedBottomOverscroll = 0.0;

    // Immediately show loading indicator and block all scrolling/interaction
    setState(() {
      _isLoading = true;
      _isRestoringScroll = true;
      _isJumpingToPage = true;
    });

    if (next && _pageUrls.isNotEmpty) {
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer!.cancel();
      }
      _currentPage = _pageUrls.length;
      _progress = 1.0;
      try {
        await _saveProgression();
      } catch (e) {
        debugPrint('Failed to save progression: $e');
      }
    }

    await _loadChapterInternal(targetChapter);
  }

  Future<void> _loadChapter(
    Chapter targetChapter, {
    int initialPage = 1,
  }) async {
    if (_isChangingChapter || _isLoading) return;
    if (targetChapter.id == _chapterId) return;

    _isChangingChapter = true;
    _accumulatedBottomOverscroll = 0.0;

    setState(() {
      _isLoading = true;
      _isRestoringScroll = true;
      _isJumpingToPage = true;
    });

    await _loadChapterInternal(targetChapter, initialPage: initialPage);
  }

  Future<void> _loadChapterInternal(
    Chapter targetChapter, {
    int initialPage = 1,
  }) async {
    _chapterCancelToken?.cancel();
    _chapterCancelToken = CancelToken();

    try {
      _apiService.incrementChapterView(
        widget.content.mangaId,
        targetChapter.id,
      );

      final pages = await _apiService.getChapterPages(
        widget.content.mangaId,
        targetChapter.id,
        cancelToken: _chapterCancelToken,
      );

      PaintingBinding.instance.imageCache.clearLiveImages();
      _pageAspectRatios.clear();
      _pageKeys.clear();
      for (int i = 0; i < pages.length; i++) {
        if (pages[i].aspectRatio != null) {
          _pageAspectRatios[i] = pages[i].aspectRatio!;
        }
      }
      await _saveProgression();

      _sessionStartTime = DateTime.now();
      _chapterInitialReadingTimeSeconds = 0;

      final targetPageUrls = pages
          .map((p) => _apiService.getLocalImageUrl(p.url, null))
          .toList();

      final safeInitialPage = initialPage.clamp(
        1,
        targetPageUrls.isEmpty ? 1 : targetPageUrls.length,
      );

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }

      setState(() {
        _pageUrls = targetPageUrls;
        _chapterId = targetChapter.id;
        _currentChapterNumber = targetChapter.chapterNumber;
        _progress = targetPageUrls.length > 1
            ? (safeInitialPage - 1) / (targetPageUrls.length - 1)
            : 0.0;
        _currentPage = safeInitialPage;
        _isLoading = false;
        _isRestoringScroll = true;
        _isJumpingToPage = true;
        _accumulatedBottomOverscroll = 0.0;
        _transformationController.value = Matrix4.identity();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
        if (_pageController.hasClients) {
          _pageController.jumpToPage(safeInitialPage - 1);
        }

        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _isRestoringScroll = false;
              _isJumpingToPage = false;
            });
          }
        });
      });

      if (safeInitialPage > 1) {
        if (_isWebtoonMode) {
          _jumpToWebtoonPage(safeInitialPage - 1);
        }
      }

      _loadInitialReadingTime(chapterId: targetChapter.id);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isRestoringScroll = false;
        _isJumpingToPage = false;
        _accumulatedBottomOverscroll = 0.0;
      });
      if (mounted) {
        AlertBanner.show(
          context,
          'Failed to load chapter: $e',
          type: AlertBannerType.error,
        );
      }
    } finally {
      _isChangingChapter = false;
      _lastChapterChangeTime = DateTime.now();
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

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale > 1.0) {
      _animateTo(
        Matrix4.identity(),
        duration: const Duration(milliseconds: 250),
      );
    } else if (_doubleTapDetails != null) {
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
    _animationController.stop();
    _animationController.reset();
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

  Future<void> _toggleFullscreen() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
      if (mounted) setState(() => _isFullscreen = !isFull);
    } else {
      if (_isFullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      if (mounted) setState(() => _isFullscreen = !_isFullscreen);
    }
  }

  void _handleKeyboard(LogicalKeyboardKey key) {
    // Global actions
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return;
    }

    if (key == LogicalKeyboardKey.space) {
      _toggleAutoScroll();
      return;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
      } else {
        Navigator.pop(context);
      }
      return;
    }

    if (key == LogicalKeyboardKey.bracketLeft) {
      _changeChapter(false);
      return;
    }

    if (key == LogicalKeyboardKey.bracketRight) {
      _changeChapter(true);
      return;
    }

    if (_isWebtoonMode) {
      if (!_scrollController.hasClients) return;

      const double scrollAmount = 200.0;
      final double pageAmount = MediaQuery.of(context).size.height * 0.8;
      final double currentOffset = _scrollController.offset;

      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS) {
        _scrollSmoothly(currentOffset + scrollAmount);
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW) {
        _scrollSmoothly(currentOffset - scrollAmount);
      } else if (key == LogicalKeyboardKey.pageDown) {
        _scrollSmoothly(currentOffset + pageAmount);
      } else if (key == LogicalKeyboardKey.pageUp) {
        _scrollSmoothly(currentOffset - pageAmount);
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        _changeChapter(true);
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA) {
        _changeChapter(false);
      }
    } else {
      if (!_pageController.hasClients) return;

      // Handle forward & backward paging considering RTL mode
      final bool isForward = _isRtlMode
          ? (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.keyA)
          : (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.pageDown ||
                key == LogicalKeyboardKey.keyD);

      final bool isBackward = _isRtlMode
          ? (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.keyD)
          : (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.pageUp ||
                key == LogicalKeyboardKey.keyA);

      if (isForward) {
        if (_currentPage < _pageUrls.length) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _changeChapter(true);
        }
      } else if (isBackward) {
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
      if (!_isLoading && !_isChangingChapter) {
        _changeChapter(true);
      }
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
        return ReaderSettingsSheet(
          isWebtoonMode: _isWebtoonMode,
          isRtlMode: _isRtlMode,
          isAutoScrolling: _isAutoScrolling,
          autoScrollSpeed: _autoScrollSpeed,
          hideMiniProgressBar: _hideMiniProgressBar,
          onWebtoonModeChanged: (val) {
            setState(() => _isWebtoonMode = val);
            Navigator.pop(context);
          },
          onRtlModeChanged: (val) {
            setState(() => _isRtlMode = val);
            Navigator.pop(context);
          },
          onAutoScrollChanged: (val) {
            _toggleAutoScroll();
            Navigator.pop(context);
          },
          onAutoScrollSpeedChanged: (val) {
            setState(() => _autoScrollSpeed = val);
          },
          onHideMiniProgressBarChanged: (val) {
            setState(() => _hideMiniProgressBar = val);
          },
        );
      },
    );
  }

  void _showChapterPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ReaderChapterPickerSheet(
          chapters: widget.content.allChapters,
          currentChapterNumber: _currentChapterNumber,
          onChapterSelected: (chapter) {
            _loadChapter(chapter);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = widget.content.allChapters;
    final hasNextChapter =
        widget.content.hasNextChapter(_chapterId, _currentChapterNumber);

    final double maxChapter = chapters.fold(
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
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          _handleKeyboard(event.logicalKey);
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (_debounceTimer?.isActive ?? false) {
            _debounceTimer?.cancel();
            _saveProgression();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    if (!_isChangingChapter && !_isLoading) {
                      _isRestoringScroll = false;
                      _isJumpingToPage = false;
                    }
                  } else if (notification is OverscrollNotification) {
                    if (_isWebtoonMode &&
                        notification.overscroll > 0 &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent &&
                        !_isLoading &&
                        !_isChangingChapter &&
                        !_isRestoringScroll &&
                        !_isJumpingToPage &&
                        !_isSliderScrolling) {
                      if (_currentPage != _pageUrls.length) {
                        setState(() {
                          _currentPage = _pageUrls.length;
                          _progress = 1.0;
                        });
                      }
                      _accumulatedBottomOverscroll += notification.overscroll;
                      if (_accumulatedBottomOverscroll >= 150) {
                        _accumulatedBottomOverscroll = 0;
                        _changeChapter(true);
                      }
                    }
                  } else if (notification is ScrollUpdateNotification) {
                    if (_isWebtoonMode &&
                        !_isLoading &&
                        !_isChangingChapter &&
                        !_isRestoringScroll &&
                        !_isJumpingToPage &&
                        !_isSliderScrolling &&
                        notification.metrics.pixels >
                            notification.metrics.maxScrollExtent) {
                      if (_currentPage != _pageUrls.length) {
                        setState(() {
                          _currentPage = _pageUrls.length;
                          _progress = 1.0;
                        });
                      }
                      final overscrollAmount =
                          notification.metrics.pixels -
                          notification.metrics.maxScrollExtent;
                      if (overscrollAmount >= 120) {
                        _accumulatedBottomOverscroll = 0;
                        _changeChapter(true);
                      }
                    }
                  } else if (notification is ScrollEndNotification) {
                    _accumulatedBottomOverscroll = 0;
                  }
                  return false;
                },
                child: ReaderContentWidget(
                  chapterId: _chapterId,
                  pageUrls: _pageUrls,
                  httpHeaders: widget.content.httpHeaders,
                  isLoading: _isLoading,
                  showUI: _showUI,
                  transformationController: _transformationController,
                  scrollController: _scrollController,
                  pageController: _pageController,
                  isWebtoonMode: _isWebtoonMode,
                  isRtlMode: _isRtlMode,
                  pageAspectRatios: _pageAspectRatios,
                  defaultAspectRatio: _calculateAverageRatio(),
                  getPageKey: _getPageKey,
                  hasNextChapter: hasNextChapter,
                  onAspectRatioResolved: (index, ratio) {
                    _pageAspectRatios[index] = ratio;
                  },
                  onPageChanged: _onPageChanged,
                  onTap: _toggleUI,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  onToggleUI: _toggleUI,
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _showUI ? 0 : -150,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: ReaderHeader(
                  mangaTitle: widget.content.mangaTitle,
                  chapterTitle: 'Chapter $currentChapterStr / $maxChapterStr',
                  isFullscreen: _isFullscreen,
                  onBack: () => Navigator.pop(context),
                  onSettings: _showSettingsBottomSheet,
                  onChapterListTap: _showChapterPickerSheet,
                  onToggleFullscreen: _toggleFullscreen,
                ),
              ),
            ),
            // Floating Auto-Scroll HUD
            if (_isAutoScrolling)
              Positioned(
                top: 80,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Auto-scroll ${_autoScrollSpeed}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggleAutoScroll,
                        child: const Icon(
                          Icons.pause_circle_outline_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Floating Debug Info HUD (Debug Mode Only)
            if (kDebugMode)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _showUI ? 70 : 20,
                left: 20,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Debug: Page $_currentPage / ${_pageUrls.length} • '
                      '${_isWebtoonMode ? 'Scroll: ${_scrollController.hasClients ? _scrollController.offset.toInt() : 0}px' : 'Paged Mode'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
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
                    child: RepaintBoundary(
                      child: ReaderBottomBar(
                        progress: _progress,
                        currentPage: _currentPage,
                        totalPages: _pageUrls.length,
                        isSliderScrolling: _isSliderScrolling,
                        isRtlMode: _isRtlMode,
                        onProgressChanged: (value) {
                          final targetPage =
                              ((value * (_pageUrls.length - 1)).round() + 1)
                                  .clamp(1, _pageUrls.length);

                          setState(() {
                            _progress = value;
                            _currentPage = targetPage;
                          });

                          if (_isWebtoonMode && _scrollController.hasClients) {
                            _isRestoringScroll = false;
                            final targetIndex = targetPage - 1;
                            final screenWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            final contentWidth = (screenWidth < 800.0
                                ? screenWidth
                                : 800.0);
                            final estimatedOffset = _calculateEstimatedOffset(
                              targetIndex,
                              contentWidth,
                            );

                            final maxScroll =
                                _scrollController.position.maxScrollExtent;
                            _scrollController.jumpTo(
                              estimatedOffset.clamp(
                                0.0,
                                maxScroll > 0 ? maxScroll : estimatedOffset,
                              ),
                            );
                          }

                          if (!_isWebtoonMode && _pageController.hasClients) {
                            _pageController.jumpToPage(_currentPage - 1);
                          }
                        },
                        onProgressChangeStart: (_) {
                          _isSliderScrolling = true;
                        },
                        onProgressChangeEnd: (_) {
                          _isSliderScrolling = false;
                          if (_isWebtoonMode) {
                            _jumpToWebtoonPage(_currentPage - 1);
                          }
                        },
                        onNextChapter: () => _changeChapter(true),
                        onPreviousChapter: () => _changeChapter(false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
    ),
  );
  }

  Future<void> _saveProgression() async {
    final isCompleted =
        _pageUrls.isNotEmpty && _currentPage >= _pageUrls.length;

    final now = DateTime.now();
    final sessionSeconds = now.difference(_sessionStartTime).inSeconds;

    _sessionStartTime = now;
    _chapterInitialReadingTimeSeconds += sessionSeconds;

    MangaProgression? existingProgression = await _progressionService
        .getProgression(widget.content.mangaId);

    List<UserChapterLog> logs = existingProgression?.chapterLogs.toList() ?? [];
    final existingLogIndex = logs.indexWhere((l) => l.chapterId == _chapterId);

    if (existingLogIndex >= 0) {
      final existingLog = logs[existingLogIndex];
      logs[existingLogIndex] = UserChapterLog(
        id: existingLog.id,
        chapterId: _chapterId,
        chapterNumber: _currentChapterNumber,
        lastReadPage: _currentPage,
        totalPages: _pageUrls.length,
        isCompleted: isCompleted,
        readingTimeSeconds: _chapterInitialReadingTimeSeconds,
        lastReadAt: now,
      );
    } else {
      logs.add(
        UserChapterLog(
          id: '',
          chapterId: _chapterId,
          chapterNumber: _currentChapterNumber,
          lastReadPage: _currentPage,
          totalPages: _pageUrls.length,
          isCompleted: isCompleted,
          readingTimeSeconds: _chapterInitialReadingTimeSeconds,
          lastReadAt: now,
        ),
      );
    }

    final progression = MangaProgression(
      id: existingProgression?.id ?? '',
      userId: existingProgression?.userId ?? '',
      mangaId: widget.content.mangaId,
      chapterLogs: logs,
      lastReadAt: now,
      totalReadingTime: existingProgression?.totalReadingTime ?? 0,
      chapterId: _chapterId,
      currentChapter: _currentChapterNumber,
      currentPage: _currentPage,
      totalPages: _pageUrls.length,
      isCompleted: isCompleted,
      readingTimeSeconds: _chapterInitialReadingTimeSeconds,
      manga: existingProgression?.manga,
    );

    try {
      await _progressionService.saveProgression(progression);
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Failed to save progress: $e',
          type: AlertBannerType.error,
        );
      }
      debugPrint('Progression save error: $e');
    }
  }
}
