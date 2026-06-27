import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_manga_reader/core/di/injection.dart';
import 'package:my_manga_reader/data/services/google_desktop_auth.dart';
import 'package:my_manga_reader/data/services/library_service.dart';
import 'package:my_manga_reader/data/services/manga_api_service.dart';
import 'package:my_manga_reader/data/services/progression_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Desktop OAuth helper – credentials are loaded from the .env file.
  late final GoogleDesktopAuth _desktopAuth = GoogleDesktopAuth(
    clientId: dotenv.env['GOOGLE_DESKTOP_CLIENT_ID'] ?? '',
    clientSecret: dotenv.env['GOOGLE_DESKTOP_CLIENT_SECRET'] ?? '',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Returns `true` when running on a desktop OS (Windows / Linux / macOS)
  /// but NOT on the web.
  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<User?> signInWithGoogle() async {
    try {
      // ── 🌐 WEB ────────────────────────────────────────────────────────────
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(provider);

        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null) {
          await getIt<MangaApiService>().loginWithFirebase(idToken);
        }

        // Load user data from API to populate local cache
        await Future.wait([
          getIt<ProgressionService>().refreshFromApi(),
          getIt<LibraryService>().refreshFromApi(),
        ]);

        return userCredential.user;
      }

      // ── 🖥️  DESKTOP (Windows / Linux / macOS) ───────────────────────────
      if (_isDesktop) {
        final result = await _desktopAuth.signIn();
        if (result == null) return null; // user cancelled

        final credential = GoogleAuthProvider.credential(
          idToken: result.idToken,
          accessToken: result.accessToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null) {
          await getIt<MangaApiService>().loginWithFirebase(idToken);
        }

        // Load user data from API to populate local cache
        await Future.wait([
          getIt<ProgressionService>().refreshFromApi(),
          getIt<LibraryService>().refreshFromApi(),
        ]);

        return userCredential.user;
      }

      // ── 🤖 ANDROID / iOS ─────────────────────────────────────────────────
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      final idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        await getIt<MangaApiService>().loginWithFirebase(idToken);
      }

      // Load user data from API to populate local cache
      await Future.wait([
        getIt<ProgressionService>().refreshFromApi(),
        getIt<LibraryService>().refreshFromApi(),
      ]);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase error: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('Unknown error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb && !_isDesktop) {
      await _googleSignIn.signOut();
    }

    // Clear backend JWT token
    await getIt<MangaApiService>().logout();

    // Clear local data store
    await Future.wait([
      getIt<ProgressionService>().clearAllProgressions(),
      getIt<LibraryService>().clearLibrary(),
    ]);

    await _auth.signOut();
  }
}
