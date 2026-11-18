import 'package:material_ui/material_ui.dart';

class AppThemeScheme {
  final String id;
  final String name;
  final String description;
  final Color primary;
  final Color secondary;

  const AppThemeScheme({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
  });

  static const AppThemeScheme defaultScheme = AppThemeScheme(
    id: 'ocean_blue',
    name: 'Ocean Blue',
    description: 'Classic & serene blue theme',
    primary: Color(0xFF3498DB),
    secondary: Color(0xFF2980B9),
  );

  static const List<AppThemeScheme> schemes = [
    defaultScheme,
    AppThemeScheme(
      id: 'emerald_green',
      name: 'Emerald Green',
      description: 'Fresh & vibrant nature green',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF059669),
    ),
    AppThemeScheme(
      id: 'crimson_red',
      name: 'Crimson Red',
      description: 'Bold & passionate red',
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFDC2626),
    ),
    AppThemeScheme(
      id: 'royal_purple',
      name: 'Royal Purple',
      description: 'Elegant & mystical violet',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFF7C3AED),
    ),
    AppThemeScheme(
      id: 'sunset_orange',
      name: 'Sunset Orange',
      description: 'Warm & energetic sunset glow',
      primary: Color(0xFFF97316),
      secondary: Color(0xFFEA580C),
    ),
    AppThemeScheme(
      id: 'sakura_pink',
      name: 'Sakura Pink',
      description: 'Soft & playful cherry blossom',
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFDB2777),
    ),
    AppThemeScheme(
      id: 'amber_gold',
      name: 'Amber Gold',
      description: 'Bright & radiant sunny amber',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFD97706),
    ),
    AppThemeScheme(
      id: 'teal_cyan',
      name: 'Teal Cyan',
      description: 'Modern & cool electric teal',
      primary: Color(0xFF06B6D4),
      secondary: Color(0xFF0891B2),
    ),
    AppThemeScheme(
      id: 'indigo_wave',
      name: 'Indigo Wave',
      description: 'Deep & refined indigo blue',
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF4F46E5),
    ),
    AppThemeScheme(
      id: 'rose_velvet',
      name: 'Rose Velvet',
      description: 'Charming & rich rose red',
      primary: Color(0xFFF43F5E),
      secondary: Color(0xFFE11D48),
    ),
  ];

  static AppThemeScheme fromId(String? id) {
    if (id == null) return defaultScheme;
    return schemes.firstWhere(
      (scheme) => scheme.id == id,
      orElse: () => defaultScheme,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeScheme &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
