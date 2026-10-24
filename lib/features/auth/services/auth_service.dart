import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/services/heartbeat_service.dart';
import '../../../core/services/notification_service.dart';
import '../../history/services/progression_service.dart';
import '../../library/services/library_service.dart';
import '../../manga_detail/services/manga_signalr_service.dart';
import 'google_desktop_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  late final GoogleDesktopAuth _desktopAuth = GoogleDesktopAuth(
    clientId: dotenv.env['GOOGLE_DESKTOP_CLIENT_ID'] ??
        dotenv.env['GOOGLE_CLIENT_ID'] ??
        dotenv.env['FIREBASE_WINDOWS_CLIENT_ID'] ??
        dotenv.env['FIREBASE_WEB_CLIENT_ID'] ??
        '',
    clientSecret: dotenv.env['GOOGLE_DESKTOP_CLIENT_SECRET'] ??
        dotenv.env['GOOGLE_CLIENT_SECRET'] ??
        '',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _handlePostLogin(String idToken) async {
    await getIt<MangaApiService>().loginWithFirebase(idToken);
    await getIt<NotificationService>().syncFcmToken();
    getIt<HeartbeatService>().start();

    final userId = getIt<MangaApiService>().userId;
    if (userId != null && userId.isNotEmpty) {
      getIt<ProgressionService>().joinUserSignalRGroup(userId);
    }

    await Future.wait([
      getIt<ProgressionService>().refreshFromApi(),
      getIt<LibraryService>().refreshFromApi(),
    ]);
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(provider);

        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null) {
          await _handlePostLogin(idToken);
        }

        return userCredential.user;
      }

      if (_isDesktop) {
        final result = await _desktopAuth.signIn();
        if (result == null) return null;

        final credential = GoogleAuthProvider.credential(
          idToken: result.idToken,
          accessToken: result.accessToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        final idToken = await userCredential.user?.getIdToken();
        if (idToken != null) {
          await _handlePostLogin(idToken);
        }

        return userCredential.user;
      }

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
        await _handlePostLogin(idToken);
      }

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
    final currentUserId = getIt<MangaApiService>().userId;

    try {
      if (!kIsWeb && !_isDesktop) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign out error: $e');
    }

    try {
      getIt<HeartbeatService>().stop();
    } catch (e) {
      debugPrint('Heartbeat stop error: $e');
    }

    // Unregister FCM Token from backend and clear topic subscriptions
    try {
      await getIt<NotificationService>().unregisterFcmToken();
    } catch (e) {
      debugPrint('Notification service unregister error: $e');
    }

    if (currentUserId != null && currentUserId.isNotEmpty) {
      try {
        await getIt<MangaSignalRService>().leaveUserGroup(currentUserId);
      } catch (_) {}
    }

    try {
      await getIt<MangaApiService>().logout();
    } catch (e) {
      debugPrint('API logout error: $e');
    }

    try {
      await Future.wait([
        getIt<ProgressionService>().clearAllProgressions(),
        getIt<LibraryService>().clearLibrary(),
      ]);
    } catch (e) {
      debugPrint('Clear local data error: $e');
    }

    await _auth.signOut();
  }
}

