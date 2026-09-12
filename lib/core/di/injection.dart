import 'package:get_it/get_it.dart';
import '../config/app_config.dart';
import '../network/manga_api_service.dart';
import '../network/sync_service.dart';
import '../services/heartbeat_service.dart';
import '../services/notification_service.dart';
import '../services/window_service.dart';
import '../theme/theme_provider.dart';
import '../services/network_status_service.dart';
import '../../features/history/services/progression_service.dart';
import '../../features/library/services/library_cache_service.dart';
import '../../features/library/services/library_service.dart';
import '../../features/manga_detail/services/manga_detail_service.dart';
import '../../features/manga_detail/services/manga_signalr_service.dart';
import '../../features/settings/services/storage_service.dart';
import '../../features/download/services/download_service.dart';

final getIt = GetIt.instance;

Future<void> setupInjection() async {
  await AppConfig.init();
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  getIt.registerSingleton<ThemeProvider>(themeProvider);

  final networkStatusService = NetworkStatusService();
  await networkStatusService.init();
  getIt.registerSingleton<NetworkStatusService>(networkStatusService);

  final mangaApiService = MangaApiService();
  await mangaApiService.init();
  getIt.registerSingleton<MangaApiService>(mangaApiService);

  final windowService = WindowService();
  await windowService.init();
  getIt.registerSingleton<WindowService>(windowService);

  final heartbeatService = HeartbeatService();
  heartbeatService.init();
  getIt.registerSingleton<HeartbeatService>(heartbeatService);

  final notificationService = NotificationService();
  getIt.registerSingleton<NotificationService>(notificationService);

  final signalRService = MangaSignalRService();
  getIt.registerSingleton<MangaSignalRService>(signalRService);

  getIt.registerLazySingleton<SyncService>(() => SyncService());
  getIt.registerLazySingleton<ProgressionService>(() => ProgressionService());
  getIt.registerLazySingleton<MangaDetailService>(() => MangaDetailService());
  getIt.registerLazySingleton<LibraryCacheService>(() => LibraryCacheService());
  getIt.registerLazySingleton<LibraryService>(() => LibraryService());
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<DownloadService>(() => DownloadService());
}

