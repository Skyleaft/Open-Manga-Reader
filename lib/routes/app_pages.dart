import 'package:flutter/material.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/main/main_screen.dart';
import '../presentation/screens/detail/manga_detail_screen.dart';
import '../presentation/screens/reader/reader_screen.dart';
import '../presentation/screens/history/history_screen.dart';
import '../presentation/screens/more/base_api_setting_screen.dart';
import '../presentation/screens/discover/search_scrap_screen.dart';
import '../data/models/manga_detail.dart';
import '../data/models/reader_content.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static const String login = '/login';
  static const String home = '/home';
  static const String detail = '/detail';
  static const String reader = '/reader';
  static const String history = '/history';
  static const String baseApiSetting = '/base_api_setting';
  static const String searchScrap = '/search_scrap';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    home: (context) => const MainScreen(),
    detail: (context) {
      final manga = ModalRoute.of(context)!.settings.arguments as MangaDetail;
      return MangaDetailScreen(manga: manga);
    },
    reader: (context) {
      final content =
          ModalRoute.of(context)!.settings.arguments as ReaderContent;
      return ReaderScreen(content: content);
    },
    history: (context) => const HistoryScreen(),
    baseApiSetting: (context) => const BaseApiSettingScreen(),
    searchScrap: (context) => const SearchScrapScreen(),
  };
}
