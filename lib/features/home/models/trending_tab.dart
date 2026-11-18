import 'package:material_ui/material_ui.dart';

class TrendingTab {
  final String label;
  final String? genre;
  final Color color;
  final IconData icon;

  const TrendingTab({
    required this.label,
    this.genre,
    required this.color,
    required this.icon,
  });
}

const List<TrendingTab> kTrendingTabs = [
  TrendingTab(
    label: 'All',
    genre: null,
    color: Color(0xFF3498DB),
    icon: Icons.local_fire_department_rounded,
  ),
  TrendingTab(
    label: 'Action',
    genre: 'Action',
    color: Color(0xFFE74C3C),
    icon: Icons.flash_on_rounded,
  ),
  TrendingTab(
    label: 'Romance',
    genre: 'Romance',
    color: Color(0xFFE91E8C),
    icon: Icons.favorite_rounded,
  ),
  TrendingTab(
    label: 'Fantasy',
    genre: 'Fantasy',
    color: Color(0xFF9B59B6),
    icon: Icons.auto_awesome_rounded,
  ),
  TrendingTab(
    label: 'Comedy',
    genre: 'Comedy',
    color: Color(0xFFF39C12),
    icon: Icons.sentiment_very_satisfied_rounded,
  ),
  TrendingTab(
    label: 'Ecchi',
    genre: 'Ecchi',
    color: Color(0xFFFF5722),
    icon: Icons.whatshot_rounded,
  ),
  TrendingTab(
    label: 'Slice of Life',
    genre: 'Slice of Life',
    color: Color(0xFF27AE60),
    icon: Icons.spa_rounded,
  ),
];
