import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show PlatformDispatcher, kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'app.dart';
import 'core/di/injection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/storage/hive_storage.dart';
import 'core/config/app_config.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive storage and migrate data from SharedPreferences if needed
  await HiveStorage.init();
  await HiveStorage.migrateFromSharedPreferences();

  // Configure Flutter ImageCache limits to prevent memory bloat
  PaintingBinding.instance.imageCache.maximumSize = 100; // max 100 cached images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // max 100MB RAM cache

  // Desktop protocol setup
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await protocolHandler.register('open-manga-reader');
  }

  // Load .env file
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Preload Google Fonts
  GoogleFonts.pendingFonts;

  // Initialize app configuration
  await AppConfig.init();

  // Setup Dependency Injection
  await setupInjection();

  // Initialize FCM Notification Service
  if (NotificationService.isSupported) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await getIt<NotificationService>().init();
  }

  // Global Flutter and Platform Error Boundaries
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught Platform Error: $error\n$stack');
    return true;
  };

  // Set default transparent system overlay on mobile
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const MyApp());
}
