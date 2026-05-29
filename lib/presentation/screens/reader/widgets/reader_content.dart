import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/reader_content.dart';
import 'app_network_image.dart';
import 'dart:math' as math;

class ReaderContentWidget extends StatelessWidget {
  final List<String> pageUrls;
  final bool isLoading;
  final bool showUI;
  final TransformationController transformationController;
  final ScrollController scrollController;
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
            : InteractiveViewer(
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
                      : const ClampingScrollPhysics(),
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
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
    );
  }
}
