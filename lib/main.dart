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

  // 1. Global Flutter and Platform Error Boundaries FIRST
  // Captures any error occurring during startup or later execution
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught Platform Error: $error\n$stack');
    return true;
  };

  // 2. Set default transparent system overlay on mobile
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Configure Flutter ImageCache limits to prevent memory bloat
  PaintingBinding.instance.imageCache.maximumSize = 100; // max 100 cached images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024; // max 100MB RAM cache

  // Desktop protocol setup
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    try {
      await protocolHandler.register('open-manga-reader');
    } catch (e) {
      debugPrint('ProtocolHandler registration error: $e');
    }
  }

  // Initialize Hive storage and migrate data safely
  try {
    await HiveStorage.init();
    await HiveStorage.migrateFromSharedPreferences();
  } catch (e, stack) {
    debugPrint('HiveStorage initialization error: $e\n$stack');
  }

  // Load .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv load warning/error: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e\n$stack');
  }

  // Preload Google Fonts
  GoogleFonts.pendingFonts;

  // Setup Dependency Injection (initializes AppConfig, ThemeProvider, etc.)
  try {
    await setupInjection();
  } catch (e, stack) {
    debugPrint('Dependency injection error: $e\n$stack');
  }

  // Initialize FCM Notification Service in the background (NON-BLOCKING)
  // Requesting permissions or fetching FCM tokens before the first frame is rendered
  // causes Android splash screen deadlocks (OnPreDrawListener cancels draw indefinitely).
  if (NotificationService.isSupported) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      getIt<NotificationService>().init().then((_) {
        // Request notification permission safely AFTER UI has drawn its first frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          getIt<NotificationService>().requestPermissions();
        });
      }).catchError((e) {
        debugPrint('NotificationService init error: $e');
      });
    } catch (e) {
      debugPrint('Error registering notification handler: $e');
    }
  }

  runApp(const MyApp());
}
