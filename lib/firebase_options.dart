import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _safeGet(String key, String fallback) {
  try {
    if (dotenv.isInitialized) {
      final val = dotenv.maybeGet(key);
      if (val != null && val.trim().isNotEmpty) {
        return val.trim();
      }
    }
  } catch (_) {}
  return fallback;
}

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _safeGet('FIREBASE_WEB_API_KEY', 'AIzaSyDgR_mJy_csEL8xuF1R2sbW9KYfXOP7dP4'),
    appId: _safeGet('FIREBASE_WEB_APP_ID', '1:933021714823:web:dad6f9ef3e4ef64e6beb22'),
    messagingSenderId: _safeGet('FIREBASE_SENDER_ID', '933021714823'),
    projectId: _safeGet('FIREBASE_PROJECT_ID', 'mykomikid'),
    authDomain: _safeGet('FIREBASE_WEB_AUTH_DOMAIN', 'mykomikid.firebaseapp.com'),
    storageBucket: _safeGet('FIREBASE_STORAGE_BUCKET', 'mykomikid.firebasestorage.app'),
    measurementId: _safeGet('FIREBASE_WEB_MEASUREMENT_ID', 'G-CYZTXLGZ9V'),
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _safeGet('FIREBASE_ANDROID_API_KEY', 'AIzaSyAmWuF42h4xPQyzK0PyAPyD4OkZtG6kLvk'),
    appId: _safeGet('FIREBASE_ANDROID_APP_ID', '1:933021714823:android:12c52e3c41c917ea6beb22'),
    messagingSenderId: _safeGet('FIREBASE_SENDER_ID', '933021714823'),
    projectId: _safeGet('FIREBASE_PROJECT_ID', 'mykomikid'),
    storageBucket: _safeGet('FIREBASE_STORAGE_BUCKET', 'mykomikid.firebasestorage.app'),
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _safeGet('FIREBASE_IOS_API_KEY', 'AIzaSyCb2JLeTrvuxG53vhnlfPjYR5W_mJTMSuw'),
    appId: _safeGet('FIREBASE_IOS_APP_ID', '1:933021714823:ios:a4b33d526b8ef3cb6beb22'),
    messagingSenderId: _safeGet('FIREBASE_SENDER_ID', '933021714823'),
    projectId: _safeGet('FIREBASE_PROJECT_ID', 'mykomikid'),
    storageBucket: _safeGet('FIREBASE_STORAGE_BUCKET', 'mykomikid.firebasestorage.app'),
    androidClientId: _safeGet('FIREBASE_ANDROID_CLIENT_ID', '933021714823-5msjvbhrpm6c4745bis90hqg40le5gcj.apps.googleusercontent.com'),
    iosClientId: _safeGet('FIREBASE_IOS_CLIENT_ID', '933021714823-k8q9t0kud5ks7k30qc6qm2e170f7j5m5.apps.googleusercontent.com'),
    iosBundleId: _safeGet('FIREBASE_IOS_BUNDLE_ID', 'com.example.myMangaReader'),
  );

  static FirebaseOptions get macos => FirebaseOptions(
    apiKey: _safeGet('FIREBASE_IOS_API_KEY', 'AIzaSyCb2JLeTrvuxG53vhnlfPjYR5W_mJTMSuw'),
    appId: _safeGet('FIREBASE_IOS_APP_ID', '1:933021714823:ios:a4b33d526b8ef3cb6beb22'),
    messagingSenderId: _safeGet('FIREBASE_SENDER_ID', '933021714823'),
    projectId: _safeGet('FIREBASE_PROJECT_ID', 'mykomikid'),
    storageBucket: _safeGet('FIREBASE_STORAGE_BUCKET', 'mykomikid.firebasestorage.app'),
    androidClientId: _safeGet('FIREBASE_ANDROID_CLIENT_ID', '933021714823-5msjvbhrpm6c4745bis90hqg40le5gcj.apps.googleusercontent.com'),
    iosClientId: _safeGet('FIREBASE_IOS_CLIENT_ID', '933021714823-k8q9t0kud5ks7k30qc6qm2e170f7j5m5.apps.googleusercontent.com'),
    iosBundleId: _safeGet('FIREBASE_IOS_BUNDLE_ID', 'com.example.myMangaReader'),
  );

  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: _safeGet('FIREBASE_WEB_API_KEY', 'AIzaSyDgR_mJy_csEL8xuF1R2sbW9KYfXOP7dP4'),
    appId: _safeGet('FIREBASE_WINDOWS_APP_ID', '1:933021714823:web:a200daf885f9f49a6beb22'),
    messagingSenderId: _safeGet('FIREBASE_SENDER_ID', '933021714823'),
    projectId: _safeGet('FIREBASE_PROJECT_ID', 'mykomikid'),
    authDomain: _safeGet('FIREBASE_WEB_AUTH_DOMAIN', 'mykomikid.firebaseapp.com'),
    storageBucket: _safeGet('FIREBASE_STORAGE_BUCKET', 'mykomikid.firebasestorage.app'),
    measurementId: _safeGet('FIREBASE_WINDOWS_MEASUREMENT_ID', 'G-93PM1WCF5P'),
  );
}
