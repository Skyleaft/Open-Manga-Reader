import 'package:flutter/material.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/main/presentation/main_screen.dart';
import '../features/manga_detail/presentation/manga_detail_screen.dart';
import '../features/manga_detail/models/manga_detail.dart';
import '../features/reader/presentation/reader_screen.dart';
import '../features/reader/models/reader_content.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/settings/presentation/base_api_setting_screen.dart';
import '../features/settings/presentation/theme_setting_screen.dart';
import '../features/discover/presentation/search_scrap_screen.dart';
import '../features/discover/presentation/advanced_recommendation_screen.dart';
import '../features/download/presentation/downloaded_chapters_screen.dart';
import '../features/settings/presentation/storage_setting_screen.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  static const String login = '/login';
  static const String home = '/home';
  static const String detail = '/detail';
  static const String reader = '/reader';
  static const String history = '/history';
  static const String baseApiSetting = '/base_api_setting';
  static const String themeSetting = '/theme_setting';
  static const String searchScrap = '/search_scrap';
  static const String advancedRecommendation = '/advanced_recommendation';
  static const String downloadedChapters = '/downloaded_chapters';
  static const String storageSetting = '/storage_setting';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    home: (context) => const MainScreen(),
    detail: (context) {
      final args = ModalRoute.of(context)!.settings.arguments;
      final MangaDetail manga;
      final String? heroTag;
      if (args is MangaDetail) {
        manga = args;
        heroTag = null;
      } else if (args is Map<String, dynamic>) {
        manga = args['manga'] as MangaDetail;
        heroTag = args['heroTag'] as String?;
      } else {
        manga = args as MangaDetail;
        heroTag = null;
      }
      return MangaDetailScreen(manga: manga, heroTag: heroTag);
    },
    reader: (context) {
      final content =
          ModalRoute.of(context)!.settings.arguments as ReaderContent;
      return ReaderScreen(content: content);
    },
    history: (context) => const HistoryScreen(),
    baseApiSetting: (context) => const BaseApiSettingScreen(),
    themeSetting: (context) => const ThemeSettingScreen(),
    searchScrap: (context) => const SearchScrapScreen(),
    advancedRecommendation: (context) => const AdvancedRecommendationScreen(),
    downloadedChapters: (context) => const DownloadedChaptersScreen(),
    storageSetting: (context) => const StorageSettingScreen(),
  };

  /// Custom transition generator for high-performance, silky-smooth navigation
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == detail) {
      final args = settings.arguments;
      final MangaDetail manga;
      final String? heroTag;
      if (args is MangaDetail) {
        manga = args;
        heroTag = null;
      } else if (args is Map<String, dynamic>) {
        manga = args['manga'] as MangaDetail;
        heroTag = args['heroTag'] as String?;
      } else {
        manga = args as MangaDetail;
        heroTag = null;
      }
      return PageRouteBuilder(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return MangaDetailScreen(manga: manga, heroTag: heroTag);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
      );
    }

    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return null;
  }
}
