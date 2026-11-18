import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_theme_scheme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyColorScheme = 'app_theme_color_scheme';

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeScheme _currentScheme = AppThemeScheme.defaultScheme;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  AppThemeScheme get currentScheme => _currentScheme;
  bool get isInitialized => _isInitialized;

  Color get primaryColor => _currentScheme.primary;

  ThemeData get lightThemeData => AppTheme.buildTheme(
        brightness: Brightness.light,
        scheme: _currentScheme,
      );

  ThemeData get darkThemeData => AppTheme.buildTheme(
        brightness: Brightness.dark,
        scheme: _currentScheme,
      );

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_keyThemeMode);
      if (modeString != null) {
        if (modeString == 'light') {
          _themeMode = ThemeMode.light;
        } else if (modeString == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
      }

      final schemeId = prefs.getString(_keyColorScheme);
      if (schemeId != null) {
        _currentScheme = AppThemeScheme.fromId(schemeId);
      }
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String modeString = 'system';
      if (mode == ThemeMode.light) {
        modeString = 'light';
      } else if (mode == ThemeMode.dark) {
        modeString = 'dark';
      }
      await prefs.setString(_keyThemeMode, modeString);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  Future<void> setColorScheme(AppThemeScheme scheme) async {
    if (_currentScheme == scheme) return;
    _currentScheme = scheme;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyColorScheme, scheme.id);
    } catch (e) {
      debugPrint('Error saving theme color scheme: $e');
    }
  }
}
