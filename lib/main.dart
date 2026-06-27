import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/di/injection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file (ignored if missing in debug; always present in release bundle)
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Preload Google Fonts to prevent debug pauses
  GoogleFonts.pendingFonts;

  // Initialize app configuration
  await AppConfig.init();

  await setupInjection();
  runApp(const MyApp());
}
