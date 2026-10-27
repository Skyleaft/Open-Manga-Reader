import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../manga_detail/models/manga_detail.dart';
import '../controllers/reader_controller.dart';
import '../models/reader_content.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reader_chapter_picker_sheet.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_header.dart';
import 'widgets/reader_settings_sheet.dart';
import 'widgets/reader_shortcuts_dialog.dart';

class ReaderScreen extends StatefulWidget {
  final ReaderContent content;

  const ReaderScreen({super.key, required this.content});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with TickerProviderStateMixin {
  late final ReaderController _controller;

  late Ticker _autoScrollTicker;
  Duration _lastTick = Duration.zero;

  final TransformationController _transformationController =
      TransformationController();
  late final ScrollController _scrollController;
  late AnimationController _animationController;
  late final PageController _pageController;

  final Map<int, GlobalKey> _pageKeys = {};
  TapDownDetails? _doubleTapDetails;
  double? _targetScrollOffset;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.imageCache.maximumSizeBytes = 250 * 1024 * 1024;

    _controller = ReaderController(content: widget.content);
    _controller.addListener(_onControllerChanged);

    _animationController = AnimationController(vsync: this);
    _autoScrollTicker = createTicker(_onAutoScrollTick);
    _pageController = PageController(
      initialPage:
          widget.content.currentPage > 1 &&
                  widget.content.currentPage <= widget.content.pageUrls.length
              ? widget.content.currentPage - 1
              : 0,
    );

    _scrollController = ScrollController();

    if (widget.content.currentPage > 1 &&
        widget.content.currentPage <= widget.content.pageUrls.length) {
      _restoreInitialScroll();
    }

    _transformationController.addListener(_onTransformationChanged);
    _scrollController.addListener(_onScroll);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
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
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    setState(() {});
  }

  GlobalKey _getPageKey(int index) {
    return _pageKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'webtoon_page_$index'),
    );
  }

  int? _getClosestVisiblePageIndex() {
    int? bestIndex;
    double minDistance = double.infinity;

    for (int i = 0; i < _controller.pageUrls.length; i++) {
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
    _controller.setJumpingToPage(true);
    _controller.setRestoringScroll(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_controller.isWebtoonMode) {
        _controller.setJumpingToPage(false);
        _controller.setRestoringScroll(false);
        return;
      }
      if (targetIndex < 0 || targetIndex >= _controller.pageUrls.length) {
        _controller.setJumpingToPage(false);
        _controller.setRestoringScroll(false);
        return;
      }

      final screenWidth = MediaQuery.of(context).size.width;
      final contentWidth = (screenWidth < 800.0 ? screenWidth : 800.0);
      final maxScroll = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : null;
      final targetOffset = explicitOffset ??
          _controller.calculateEstimatedOffset(
            targetIndex,
            contentWidth,
            maxScrollExtent: maxScroll,
            hasClients: _scrollController.hasClients,
          );

      if (_scrollController.hasClients) {
        final safeTarget = maxScroll != null && maxScroll > 0
            ? targetOffset.clamp(0.0, maxScroll)
            : targetOffset.clamp(0.0, double.infinity);
        _scrollController.jumpTo(safeTarget);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          _controller.setJumpingToPage(false);
          _controller.setRestoringScroll(false);
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

          final newProgress = _controller.pageUrls.length > 1
              ? (targetIndex / (_controller.pageUrls.length - 1)).clamp(0.0, 1.0)
              : 0.0;
          _controller.updatePageAndProgress(targetIndex + 1, newProgress);
          _controller.setRestoringScroll(false);
          _controller.debounceSaveProgression();

          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _controller.setJumpingToPage(false);
            }
          });
        } else if (retryCount < 4) {
          final visibleIndex = _getClosestVisiblePageIndex();
          if (visibleIndex != null && visibleIndex != targetIndex) {
            final avgRatio = _controller.calculateAverageRatio();
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
            if (targetIndex >= _controller.pageUrls.length - 1 &&
                _scrollController.hasClients) {
              final maxScroll = _scrollController.position.maxScrollExtent;
              if (maxScroll > 0) {
                _scrollController.jumpTo(maxScroll);
              }
            }
            _controller.setRestoringScroll(false);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _controller.setJumpingToPage(false);
              }
            });
            _onScroll();
          }
        } else {
          if (targetIndex >= _controller.pageUrls.length - 1 &&
              _scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            if (maxScroll > 0) {
              _scrollController.jumpTo(maxScroll);
            }
          }
          _controller.setRestoringScroll(false);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _controller.setJumpingToPage(false);
            }
          });
          _onScroll();
        }
      });
    });
  }

  void _restoreInitialScroll() {
    if (widget.content.currentPage <= 1 || _controller.pageUrls.isEmpty) {
      _controller.setRestoringScroll(false);
      return;
    }
    _jumpToWebtoonPage(widget.content.currentPage - 1);
  }

  void _onScroll() {
    if (_controller.isSliderScrolling ||
        _controller.isRestoringScroll ||
        _controller.isJumpingToPage ||
        _controller.isChangingChapter ||
        _controller.isLoading) {
      return;
    }
    if (!_scrollController.hasClients || _controller.pageUrls.isEmpty) {
      return;
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final maxScroll = position.maxScrollExtent;

    if (!_controller.isWebtoonMode) {
      return;
    }

    int? activePage;
    final screenHeight = MediaQuery.of(context).size.height;
    final targetYThreshold = screenHeight * 0.35;

    // 1. If at or near the bottom of the chapter, immediately set activePage to the last page
    if (maxScroll > 0 &&
        (position.pixels >= maxScroll - 80 || position.extentAfter <= 80)) {
      activePage = _controller.pageUrls.length;
    } else {
      for (int i = 0; i < _controller.pageUrls.length; i++) {
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
        for (int i = 0; i < _controller.pageUrls.length; i++) {
          final ratio = _controller.pageAspectRatios[i] ?? 1.4;
          final pageHeight = contentWidth * ratio;
          if (focalPoint < cumulativeOffset + pageHeight) {
            activePage = i + 1;
            break;
          }
          cumulativeOffset += pageHeight;
        }
        activePage ??= _controller.pageUrls.length;
      }
    }

    if (activePage != null && activePage != _controller.currentPage) {
      final newProgress = _controller.pageUrls.length > 1
          ? ((activePage - 1) / (_controller.pageUrls.length - 1)).clamp(0.0, 1.0)
          : 1.0;

      // Isolated update: doesn't trigger full ReaderScreen rebuild!
      _controller.updatePageAndProgress(activePage, newProgress);
      _controller.debounceSaveProgression();
    }
  }

  void _changeChapter(bool next) {
    HapticFeedback.mediumImpact();
    _controller.changeChapter(
      next: next,
      onChapterNotFound: () {
        if (!mounted) return;
        AlertBanner.show(
          context,
          next ? 'This is the latest chapter' : 'This is the first chapter',
          type: AlertBannerType.info,
        );
        if (_pageController.hasClients &&
            _controller.currentPage > _controller.pageUrls.length) {
          _pageController.animateToPage(
            _controller.pageUrls.length - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      onBeforeLoad: () {
        _targetScrollOffset = null;
        _pageKeys.clear();
        _transformationController.value = Matrix4.identity();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      },
      onLoaded: () {
        _pageKeys.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_controller.currentPage - 1);
          }

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _controller.setRestoringScroll(false);
              _controller.setJumpingToPage(false);
            }
          });
        });

        if (_controller.currentPage > 1 && _controller.isWebtoonMode) {
          _jumpToWebtoonPage(_controller.currentPage - 1);
        }
      },
      onError: (msg) {
        if (mounted) {
          AlertBanner.show(context, msg, type: AlertBannerType.error);
        }
      },
    );
  }

  void _loadChapter(Chapter targetChapter, {int initialPage = 1}) {
    HapticFeedback.mediumImpact();
    _controller.loadChapter(
      targetChapter,
      initialPage: initialPage,
      onBeforeLoad: () {
        _targetScrollOffset = null;
        _pageKeys.clear();
        _transformationController.value = Matrix4.identity();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      },
      onLoaded: () {
        _pageKeys.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
          if (_pageController.hasClients) {
            _pageController.jumpToPage(initialPage - 1);
          }

          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _controller.setRestoringScroll(false);
              _controller.setJumpingToPage(false);
            }
          });
        });

        if (initialPage > 1 && _controller.isWebtoonMode) {
          _jumpToWebtoonPage(initialPage - 1);
        }
      },
      onError: (msg) {
        if (mounted) {
          AlertBanner.show(context, msg, type: AlertBannerType.error);
        }
      },
    );
  }

  void _retryChapter() {
    _controller.retryCurrentChapter(
      onBeforeLoad: () {
        _targetScrollOffset = null;
        _pageKeys.clear();
        _transformationController.value = Matrix4.identity();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      },
      onLoaded: () {
        _pageKeys.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_controller.currentPage - 1);
          }
        });
      },
      onError: (msg) {
        if (mounted) {
          AlertBanner.show(context, msg, type: AlertBannerType.error);
        }
      },
    );
  }

  void _onAutoScrollTick(Duration elapsed) {
    if (!_controller.isAutoScrolling) return;

    if (_controller.isWebtoonMode) {
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
          (delta.inMilliseconds / 1000) * 50 * _controller.autoScrollSpeed;
      _scrollController.jumpTo(offset + pixelsToMove);
    } else {
      if (!_pageController.hasClients) return;

      final delta = elapsed - _lastTick;
      final pageFlipDuration = Duration(
        milliseconds: (8000 / _controller.autoScrollSpeed).round(),
      );

      if (delta >= pageFlipDuration) {
        _lastTick = elapsed;
        if (_controller.currentPage < _controller.pageUrls.length) {
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
    _controller.toggleAutoScroll();
    if (_controller.isAutoScrolling) {
      _lastTick = Duration.zero;
      _autoScrollTicker.start();
    } else {
      _autoScrollTicker.stop();
    }
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

  bool _handleKeyboard(LogicalKeyboardKey key) {
    // Global actions
    if (key == LogicalKeyboardKey.keyF) {
      _controller.toggleFullscreen();
      return true;
    }

    if (key == LogicalKeyboardKey.space) {
      _toggleAutoScroll();
      return true;
    }

    if (key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.keyH) {
      ReaderShortcutsDialog.show(context);
      return true;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_controller.isFullscreen) {
        _controller.toggleFullscreen();
      } else {
        Navigator.pop(context);
      }
      return true;
    }

    if (key == LogicalKeyboardKey.bracketLeft) {
      _changeChapter(false);
      return true;
    }

    if (key == LogicalKeyboardKey.bracketRight) {
      _changeChapter(true);
      return true;
    }

    if (_controller.isWebtoonMode) {
      if (!_scrollController.hasClients) return false;

      const double scrollAmount = 200.0;
      final double pageAmount = MediaQuery.of(context).size.height * 0.8;

      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS) {
        _scrollSmoothly(scrollAmount);
        return true;
      } else if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW) {
        _scrollSmoothly(-scrollAmount);
        return true;
      } else if (key == LogicalKeyboardKey.pageDown) {
        _scrollSmoothly(pageAmount);
        return true;
      } else if (key == LogicalKeyboardKey.pageUp) {
        _scrollSmoothly(-pageAmount);
        return true;
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        _changeChapter(true);
        return true;
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA) {
        _changeChapter(false);
        return true;
      }
    } else {
      if (!_pageController.hasClients) return false;

      final bool isForward = _controller.isRtlMode
          ? (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.keyA)
          : (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.pageDown ||
                key == LogicalKeyboardKey.keyD);

      final bool isBackward = _controller.isRtlMode
          ? (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.keyD)
          : (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.pageUp ||
                key == LogicalKeyboardKey.keyA);

      if (isForward) {
        if (_controller.currentPage < _controller.pageUrls.length) {
          _pageController.animateToPage(
            _controller.currentPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _changeChapter(true);
        }
        return true;
      } else if (isBackward) {
        if (_controller.currentPage > 1) {
          _pageController.animateToPage(
            _controller.currentPage - 2,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _changeChapter(false);
        }
        return true;
      }
    }

    return false;
  }

  void _scrollSmoothly(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final min = position.minScrollExtent;

    final current = _targetScrollOffset ?? _scrollController.offset;
    final target = (current + delta).clamp(min, max);
    _targetScrollOffset = target;

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      if (_targetScrollOffset == target) {
        _targetScrollOffset = null;
      }
    });
  }

  void _onPageChanged(int index) {
    if (_controller.pageUrls.isEmpty) return;

    if (index == _controller.pageUrls.length) {
      if (!_controller.isLoading && !_controller.isChangingChapter) {
        _changeChapter(true);
      }
      return;
    }

    final page = index + 1;
    final progress =
        (index / (_controller.pageUrls.length - 1)).clamp(0.0, 1.0);
    _controller.updatePageAndProgress(page, progress);
    _controller.debounceSaveProgression();
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ReaderSettingsSheet(
          isWebtoonMode: _controller.isWebtoonMode,
          isRtlMode: _controller.isRtlMode,
          isAutoScrolling: _controller.isAutoScrolling,
          autoScrollSpeed: _controller.autoScrollSpeed,
          hideMiniProgressBar: _controller.hideMiniProgressBar,
          onWebtoonModeChanged: (val) {
            _controller.setWebtoonMode(val);
            Navigator.pop(context);
          },
          onRtlModeChanged: (val) {
            _controller.setRtlMode(val);
            Navigator.pop(context);
          },
          onAutoScrollChanged: (val) {
            _toggleAutoScroll();
            Navigator.pop(context);
          },
          onAutoScrollSpeedChanged: (val) {
            _controller.setAutoScrollSpeed(val);
          },
          onHideMiniProgressBarChanged: (val) {
            _controller.setHideMiniProgressBar(val);
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
          chapters: _controller.content.allChapters,
          currentChapterNumber: _controller.currentChapterNumber,
          onChapterSelected: (chapter) {
            _loadChapter(chapter);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _controller.content.allChapters;
    final hasNextChapter = _controller.content.hasNextChapter(
      _controller.chapterId,
      _controller.currentChapterNumber,
    );

    final double maxChapter = chapters.fold(
      0.0,
      (max, c) => c.chapterNumber > max ? c.chapterNumber : max,
    );
    final String maxChapterStr = maxChapter % 1 == 0
        ? maxChapter.toInt().toString()
        : maxChapter.toString();
    final String currentChapterStr = _controller.currentChapterNumber % 1 == 0
        ? _controller.currentChapterNumber.toInt().toString()
        : _controller.currentChapterNumber.toString();

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (_handleKeyboard(event.logicalKey)) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          _controller.cancelDebounceTimer();
          _controller.saveProgression();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is UserScrollNotification) {
                    _targetScrollOffset = null;
                    if (!_controller.isChangingChapter &&
                        !_controller.isLoading) {
                      _controller.setRestoringScroll(false);
                      _controller.setJumpingToPage(false);
                    }
                  } else if (notification is OverscrollNotification) {
                    if (_controller.isWebtoonMode &&
                        notification.overscroll > 0 &&
                        notification.dragDetails != null &&
                        notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent &&
                        !_controller.isLoading &&
                        !_controller.isChangingChapter &&
                        !_controller.isRestoringScroll &&
                        !_controller.isJumpingToPage &&
                        !_controller.isSliderScrolling) {
                      if (_controller.currentPage !=
                          _controller.pageUrls.length) {
                        _controller.updatePageAndProgress(
                          _controller.pageUrls.length,
                          1.0,
                        );
                      }
                      _controller
                          .addAccumulatedBottomOverscroll(notification.overscroll);
                      if (_controller.accumulatedBottomOverscroll >= 150) {
                        _controller.setAccumulatedBottomOverscroll(0);
                        _changeChapter(true);
                      }
                    }
                  } else if (notification is ScrollUpdateNotification) {
                    if (_controller.isWebtoonMode &&
                        notification.dragDetails != null &&
                        !_controller.isLoading &&
                        !_controller.isChangingChapter &&
                        !_controller.isRestoringScroll &&
                        !_controller.isJumpingToPage &&
                        !_controller.isSliderScrolling &&
                        notification.metrics.pixels >
                            notification.metrics.maxScrollExtent) {
                      if (_controller.currentPage !=
                          _controller.pageUrls.length) {
                        _controller.updatePageAndProgress(
                          _controller.pageUrls.length,
                          1.0,
                        );
                      }
                      final overscrollAmount = notification.metrics.pixels -
                          notification.metrics.maxScrollExtent;
                      if (overscrollAmount >= 150) {
                        _controller.setAccumulatedBottomOverscroll(0);
                        _changeChapter(true);
                      }
                    }
                  } else if (notification is ScrollEndNotification) {
                    _controller.setAccumulatedBottomOverscroll(0);
                  }
                  return false;
                },
                child: ReaderContentWidget(
                  chapterId: _controller.chapterId,
                  pageUrls: _controller.pageUrls,
                  httpHeaders: _controller.content.httpHeaders,
                  isLoading: _controller.isLoading,
                  showUI: _controller.showUI,
                  transformationController: _transformationController,
                  scrollController: _scrollController,
                  pageController: _pageController,
                  isWebtoonMode: _controller.isWebtoonMode,
                  isRtlMode: _controller.isRtlMode,
                  pageAspectRatios: _controller.pageAspectRatios,
                  defaultAspectRatio: _controller.calculateAverageRatio(),
                  getPageKey: _getPageKey,
                  hasNextChapter: hasNextChapter,
                  onAspectRatioResolved: (index, ratio) {
                    _controller.setPageAspectRatio(index, ratio);
                  },
                  onPageChanged: _onPageChanged,
                  onTap: _controller.toggleUI,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  onToggleUI: _controller.toggleUI,
                ),
              ),

              // Dedicated Error State & Retry Overlay (Center of reader)
              if (_controller.errorMessage != null &&
                  _controller.pageUrls.isEmpty &&
                  !_controller.isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13151B)
                                .withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cloud_off_rounded,
                                  color: Colors.redAccent,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Failed to Load Chapter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _controller.errorMessage!,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.arrow_back_rounded,
                                        size: 16),
                                    label: const Text('Back'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                        color: Colors.white24,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _retryChapter,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Animated Reader Header
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                top: _controller.showUI ? 0 : -150,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: ReaderHeader(
                    mangaTitle: _controller.content.mangaTitle,
                    chapterTitle: 'Chapter $currentChapterStr / $maxChapterStr',
                    isFullscreen: _controller.isFullscreen,
                    onBack: () => Navigator.pop(context),
                    onSettings: _showSettingsBottomSheet,
                    onChapterListTap: _showChapterPickerSheet,
                    onToggleFullscreen: _controller.toggleFullscreen,
                    onShowShortcuts: () => ReaderShortcutsDialog.show(context),
                  ),
                ),
              ),

              // Glassmorphic Floating Auto-Scroll HUD
              if (_controller.isAutoScrolling)
                Positioned(
                  top: 80,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.70),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 10,
                            ),
                          ],
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
                              'Auto-scroll ${_controller.autoScrollSpeed}x',
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
                  ),
                ),

              // Glassmorphic Floating Debug Info HUD (Debug Mode Only)
              if (kDebugMode)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: _controller.showUI ? 70 : 20,
                  left: 20,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: _controller.currentPageNotifier,
                            builder: (context, curPage, _) {
                              return Text(
                                'Debug: Page $curPage / ${_controller.pageUrls.length} • '
                                '${_controller.isWebtoonMode ? 'Scroll: ${_scrollController.hasClients ? _scrollController.offset.toInt() : 0}px' : 'Paged Mode'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Pull-to-Next Chapter Interactive Overscroll Pill (Webtoon Mode)
              ValueListenableBuilder<double>(
                valueListenable: _controller.accumulatedBottomOverscrollNotifier,
                builder: (context, overscroll, _) {
                  final isVisible = overscroll > 10;
                  final isTriggered = overscroll >= 150;
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    bottom: isVisible ? 78 : -80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isTriggered
                                    ? const Color(0xFF10B981)
                                    : AppColors.primary.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isTriggered
                                          ? const Color(0xFF10B981)
                                          : AppColors.primary)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTriggered
                                      ? Icons.check_circle_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: isTriggered
                                      ? const Color(0xFF10B981)
                                      : AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isTriggered
                                      ? 'Release for Next Chapter'
                                      : 'Pull for Next Chapter (${(overscroll / 150 * 100).clamp(0, 100).toInt()}%)',
                                  style: TextStyle(
                                    color: isTriggered
                                        ? const Color(0xFF10B981)
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Animated Reader Bottom Bar (Isolated via ListenableBuilder)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _controller.showUI ? 20 : -350,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _controller.currentPageNotifier,
                            _controller.progressNotifier,
                          ]),
                          builder: (context, _) {
                            return ReaderBottomBar(
                              progress: _controller.progress,
                              currentPage: _controller.currentPage,
                              totalPages: _controller.pageUrls.length,
                              isSliderScrolling: _controller.isSliderScrolling,
                              isRtlMode: _controller.isRtlMode,
                              onProgressChanged: (value) {
                                final targetPage =
                                    ((value * (_controller.pageUrls.length - 1))
                                                .round() +
                                            1)
                                        .clamp(1, _controller.pageUrls.length);

                                _controller.updatePageAndProgress(
                                  targetPage,
                                  value,
                                );

                                if (_controller.isWebtoonMode &&
                                    _scrollController.hasClients) {
                                  _controller.setRestoringScroll(false);
                                  final targetIndex = targetPage - 1;
                                  final screenWidth = MediaQuery.of(
                                    context,
                                  ).size.width;
                                  final contentWidth = (screenWidth < 800.0
                                      ? screenWidth
                                      : 800.0);
                                  final maxScroll = _scrollController
                                      .position.maxScrollExtent;
                                  final estimatedOffset =
                                      _controller.calculateEstimatedOffset(
                                    targetIndex,
                                    contentWidth,
                                    maxScrollExtent: maxScroll,
                                    hasClients: _scrollController.hasClients,
                                  );

                                  _scrollController.jumpTo(
                                    estimatedOffset.clamp(
                                      0.0,
                                      maxScroll > 0
                                          ? maxScroll
                                          : estimatedOffset,
                                    ),
                                  );
                                }

                                if (!_controller.isWebtoonMode &&
                                    _pageController.hasClients) {
                                  _pageController.jumpToPage(
                                    _controller.currentPage - 1,
                                  );
                                }
                              },
                              onProgressChangeStart: (_) {
                                _controller.setSliderScrolling(true);
                              },
                              onProgressChangeEnd: (_) {
                                _controller.setSliderScrolling(false);
                                if (_controller.isWebtoonMode) {
                                  _jumpToWebtoonPage(
                                    _controller.currentPage - 1,
                                  );
                                }
                              },
                              onNextChapter: () => _changeChapter(true),
                              onPreviousChapter: () => _changeChapter(false),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Mini Progress Bar (Isolated via ValueListenableBuilder)
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
                        opacity: _controller.showUI ||
                                _controller.hideMiniProgressBar
                            ? 0
                            : 1,
                        child: ValueListenableBuilder<int>(
                          valueListenable: _controller.currentPageNotifier,
                          builder: (context, curPage, _) {
                            if (_controller.pageUrls.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Row(
                              children: List.generate(
                                _controller.pageUrls.length,
                                (index) {
                                  final pageNumber = index + 1;
                                  final isRead = pageNumber <= curPage;
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
                                },
                              ),
                            );
                          },
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
}
