import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/app_colors.dart';

class ReaderSettingsSheet extends StatelessWidget {
  final bool isWebtoonMode;
  final bool isRtlMode;
  final bool isAutoScrolling;
  final double autoScrollSpeed;
  final bool hideMiniProgressBar;
  final ValueChanged<bool> onWebtoonModeChanged;
  final ValueChanged<bool> onRtlModeChanged;
  final ValueChanged<bool> onAutoScrollChanged;
  final ValueChanged<double> onAutoScrollSpeedChanged;
  final ValueChanged<bool> onHideMiniProgressBarChanged;

  const ReaderSettingsSheet({
    super.key,
    required this.isWebtoonMode,
    required this.isRtlMode,
    required this.isAutoScrolling,
    required this.autoScrollSpeed,
    required this.hideMiniProgressBar,
    required this.onWebtoonModeChanged,
    required this.onRtlModeChanged,
    required this.onAutoScrollChanged,
    required this.onAutoScrollSpeedChanged,
    required this.onHideMiniProgressBarChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
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
                          isSelected: isWebtoonMode,
                          onTap: () => onWebtoonModeChanged(true),
                        ),
                        _buildModeSegment(
                          label: 'Paged',
                          isSelected: !isWebtoonMode,
                          onTap: () => onWebtoonModeChanged(false),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isWebtoonMode) ...[
                  const SizedBox(height: 20),
                  _buildSettingRow(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Reading Direction',
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
                            label: 'LTR (Left to Right)',
                            isSelected: !isRtlMode,
                            onTap: () => onRtlModeChanged(false),
                          ),
                          _buildModeSegment(
                            label: 'RTL (Manga)',
                            isSelected: isRtlMode,
                            onTap: () => onRtlModeChanged(true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildSettingRow(
                  icon: Icons.play_arrow_outlined,
                  title: 'Auto Scroll',
                  trailing: Switch.adaptive(
                    value: isAutoScrolling,
                    activeTrackColor: AppColors.primary,
                    onChanged: onAutoScrollChanged,
                  ),
                ),
                if (isAutoScrolling) ...[
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
                          value: autoScrollSpeed,
                          min: 0.5,
                          max: 3.0,
                          divisions: 5,
                          activeColor: AppColors.primary,
                          inactiveColor: Colors.white10,
                          label: '${autoScrollSpeed}x',
                          onChanged: onAutoScrollSpeedChanged,
                        ),
                      ),
                      Text(
                        '${autoScrollSpeed}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _buildSettingRow(
                  icon: Icons.linear_scale,
                  title: 'Hide Mini Progress Bar',
                  trailing: Switch.adaptive(
                    value: hideMiniProgressBar,
                    activeTrackColor: AppColors.primary,
                    onChanged: onHideMiniProgressBarChanged,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
}
