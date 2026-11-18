import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../manga_detail/models/manga_detail.dart';

class ReaderChapterPickerSheet extends StatelessWidget {
  final List<Chapter> chapters;
  final double currentChapterNumber;
  final ValueChanged<Chapter> onChapterSelected;

  const ReaderChapterPickerSheet({
    super.key,
    required this.chapters,
    required this.currentChapterNumber,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
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
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chapters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${chapters.length} chapters',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final isCurrent =
                        chapter.chapterNumber == currentChapterNumber;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      title: Text(
                        chapter.title.isNotEmpty
                            ? chapter.title
                            : 'Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}',
                        style: TextStyle(
                          color: isCurrent ? AppColors.primary : Colors.white,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: chapter.title.isNotEmpty
                          ? Text(
                              'Chapter ${chapter.chapterNumber % 1 == 0 ? chapter.chapterNumber.toInt() : chapter.chapterNumber}',
                              style: TextStyle(
                                color: isCurrent
                                    ? AppColors.primary.withValues(alpha: 0.8)
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isCurrent
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (!isCurrent) {
                          onChapterSelected(chapter);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
