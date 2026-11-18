import 'package:material_ui/material_ui.dart';
import '../di/injection.dart';
import '../theme/theme_provider.dart';

class AppColors {
  static const Color defaultPrimary = Color.fromRGBO(52, 152, 219, 1);
  static const Color defaultSecondary = Color.fromARGB(255, 40, 59, 75);

  static Color get primary {
    if (getIt.isRegistered<ThemeProvider>()) {
      return getIt<ThemeProvider>().primaryColor;
    }
    return defaultPrimary;
  }

  static Color get secondary {
    if (getIt.isRegistered<ThemeProvider>()) {
      return getIt<ThemeProvider>().currentScheme.secondary;
    }
    return defaultSecondary;
  }

  static const Color backgroundLight = Color.fromRGBO(232, 246, 248, 1);
  static const Color backgroundDark = Color.fromRGBO(28, 40, 51, 1);
  static const Color cardDark = Color.fromRGBO(38, 50, 56, 1);

  static const Color textLight = Color(0xFF1E293B); // slate-900
  static const Color textDark = Color(0xFFF1F5F9); // slate-100

  static const Color error = Color(0xFFEF4444);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
}
