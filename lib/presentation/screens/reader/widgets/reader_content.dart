import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'app_network_image.dart';
import 'dart:math' as math;

class ReaderContentWidget extends StatelessWidget {
  final List<String> pageUrls;
  final bool isLoading;
  final bool showUI;
  final TransformationController transformationController;
  final ScrollController scrollController;
  final PageController pageController;
  final bool isWebtoonMode;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;
  final GestureTapDownCallback onDoubleTapDown;
  final GestureTapCallback onDoubleTap;
  final VoidCallback onToggleUI;

  const ReaderContentWidget({
    super.key,
    required this.pageUrls,
    required this.isLoading,
    required this.showUI,
    required this.transformationController,
    required this.scrollController,
    required this.pageController,
    required this.isWebtoonMode,
    required this.onPageChanged,
    required this.onTap,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.onToggleUI,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTapDown: onDoubleTapDown,
        onDoubleTap: onDoubleTap,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : isWebtoonMode
            ? InteractiveViewer(
                transformationController: transformationController,
                minScale: 1.0,
                maxScale: 5.0,
                scaleEnabled: false,
                panEnabled:
                    transformationController.value.getMaxScaleOnAxis() > 1,
                boundaryMargin: EdgeInsets.zero,
                clipBehavior: Clip.none,
                trackpadScrollCausesScale: false,
                child: CustomScrollView(
                  controller: scrollController,
                  cacheExtent: 3000,
                  physics:
                      transformationController.value.getMaxScaleOnAxis() > 1
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final url = pageUrls[index];

                        final contentWidth = math.min(screenWidth, 800.0);
                        final imageHeight = contentWidth * 1.5;

                        return Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: contentWidth,
                            child: AppNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.fitWidth,
                              width: contentWidth,
                              gaplessPlayback: true,
                              placeholder: Container(
                                height: imageHeight,
                                width: contentWidth,
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: Container(
                                height: imageHeight,
                                color: Colors.black,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: pageUrls.isEmpty ? 0 : pageUrls.length),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                color: Colors.white30,
                                size: 28,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pull up to next chapter',
                                style: TextStyle(
                                  color: Colors.white30,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              )
            : PageView.builder(
                controller: pageController,
                onPageChanged: onPageChanged,
                itemCount: pageUrls.isEmpty ? 0 : pageUrls.length + 1,
                itemBuilder: (context, index) {
                  if (index == pageUrls.length) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Swipe again to load next chapter',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final url = pageUrls[index];
                  final contentWidth = math.min(screenWidth, 800.0);
                  return Center(
                    child: SingleChildScrollView(
                      child: AppNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        width: contentWidth,
                        gaplessPlayback: true,
                        placeholder: Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: Container(
                          color: Colors.black,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
