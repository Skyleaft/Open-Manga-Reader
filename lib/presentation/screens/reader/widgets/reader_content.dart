import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/reader_content.dart';
import 'app_network_image.dart';

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
                trackpadScrollCausesScale: false,
                child: CustomScrollView(
                  controller: scrollController,
                  cacheExtent: 5000,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final url = pageUrls[index];

                        return AppNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.fitWidth,
                          width: screenWidth,
                          gaplessPlayback: true,
                          placeholder: Container(
                            height: screenWidth * 1.5,
                            width: screenWidth,
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: Container(
                            height: 200,
                            color: Colors.black,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white24,
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
