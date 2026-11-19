import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/manga_detail/models/manga_detail.dart';
import '../../routes/app_pages.dart';
import '../di/injection.dart';
import '../network/manga_api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'Handling background FCM message: ${message.messageId}, data: ${message.data}',
  );
}

class NotificationService {
  static const String _subscribedTopicsKey = 'fcm_subscribed_topics';
  static const String _lastFcmTokenKey = 'fcm_last_registered_token';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'manga_updates',
    'Manga Updates',
    description: 'Notifications for new chapter releases and library updates',
    importance: Importance.max,
    playSound: true,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? get _messaging =>
      isSupported ? FirebaseMessaging.instance : null;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  String? _pendingMangaIdToNavigate;

  static bool get isSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  Future<void> init() async {
    if (!isSupported) {
      debugPrint('FCM NotificationService is not supported on this platform.');
      return;
    }

    try {
      await _initLocalNotifications();
      await _initMessageListeners();
      await _checkInitialMessage();
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  /// Request runtime notification permissions safely after UI is ready.
  Future<void> requestPermissions() async {
    await _requestPermissions();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationPayload(payload);
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);
    }
  }

  Future<void> _requestPermissions() async {
    if (_messaging == null) return;

    try {
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        'FCM Notification permission status: ${settings.authorizationStatus}',
      );

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  Future<void> _initMessageListeners() async {
    if (_messaging == null) return;

    // 1. Foreground FCM messages -> display local notification
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      debugPrint('Received foreground FCM message: ${message.messageId}');
      _showLocalNotification(message);
    });

    // 2. Background FCM messages clicked by user
    _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        debugPrint('App opened from background FCM message: ${message.data}');
        _handleRemoteMessageClick(message);
      },
    );

    // 3. Token refresh listener
    _tokenRefreshSubscription = _messaging!.onTokenRefresh.listen((
      newToken,
    ) async {
      debugPrint('FCM Token refreshed: $newToken');
      await _registerTokenWithBackend(newToken);
    });
  }

  Future<void> _checkInitialMessage() async {
    if (_messaging == null) return;

    try {
      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'App launched from terminated state via FCM: ${initialMessage.data}',
        );
        _handleRemoteMessageClick(initialMessage);
      }
    } catch (e) {
      debugPrint('Error checking initial FCM message: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title =
        notification?.title ?? data['mangaTitle'] ?? 'New Chapter Available';
    final body =
        notification?.body ??
        (data['chapterNumber'] != null
            ? 'Chapter ${data['chapterNumber']} has been released!'
            : 'A new chapter is ready to read.');

    final mangaId = data['mangaId'] as String?;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );

    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: mangaId ?? jsonEncode(data),
    );
  }

  void _handleRemoteMessageClick(RemoteMessage message) {
    final mangaId = message.data['mangaId'] as String?;
    if (mangaId != null && mangaId.isNotEmpty) {
      navigateToMangaDetail(mangaId);
    }
  }

  void _handleNotificationPayload(String payload) {
    try {
      if (payload.startsWith('{') && payload.endsWith('}')) {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final mangaId = decoded['mangaId'] as String?;
        if (mangaId != null && mangaId.isNotEmpty) {
          navigateToMangaDetail(mangaId);
          return;
        }
      }
      navigateToMangaDetail(payload);
    } catch (e) {
      debugPrint('Error parsing notification payload "$payload": $e');
    }
  }

  Future<void> navigateToMangaDetail(String mangaId) async {
    final navState = AppRoutes.navigatorKey.currentState;
    if (navState == null) {
      _pendingMangaIdToNavigate = mangaId;
      return;
    }

    try {
      final apiService = getIt<MangaApiService>();
      final mangaData = await apiService.getMangaDetail(mangaId);
      final manga = MangaDetail.fromMap(mangaData);

      AppRoutes.navigatorKey.currentState?.pushNamed(
        AppRoutes.detail,
        arguments: manga,
      );
    } catch (e) {
      debugPrint('Error navigating to manga detail from notification: $e');
    }
  }

  void handlePendingNavigation() {
    if (_pendingMangaIdToNavigate != null) {
      final mangaId = _pendingMangaIdToNavigate!;
      _pendingMangaIdToNavigate = null;
      navigateToMangaDetail(mangaId);
    }
  }

  // --- FCM Token Registration with Backend ---

  Future<void> syncFcmToken() async {
    if (!isSupported || _messaging == null) return;

    try {
      final token = await _messaging!.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('Error fetching FCM token: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final apiService = getIt<MangaApiService>();
      if (apiService.jwtToken == null) {
        debugPrint('Skipping FCM registration: User not authenticated yet.');
        return;
      }

      await apiService.registerFcmToken(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastFcmTokenKey, token);
      debugPrint('Successfully registered FCM token with backend server.');
    } catch (e) {
      debugPrint('Failed to register FCM token with backend server: $e');
    }
  }

  Future<void> unregisterFcmToken() async {
    if (!isSupported) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastToken =
          prefs.getString(_lastFcmTokenKey) ?? await _messaging?.getToken();

      // 1. Unsubscribe from topics while token is still active on FCM server
      await clearAllSubscribedTopics();

      // 2. Unregister token from backend
      if (lastToken != null && lastToken.isNotEmpty) {
        final apiService = getIt<MangaApiService>();
        try {
          await apiService.unregisterFcmToken(lastToken);
        } catch (_) {}
      }

      // 3. Delete FCM token
      try {
        await _messaging?.deleteToken();
      } catch (e) {
        debugPrint('Error deleting FCM token: $e');
      }

      await prefs.remove(_lastFcmTokenKey);
      debugPrint('Successfully unregistered FCM token.');
    } catch (e) {
      debugPrint('Error unregistering FCM token: $e');
    }
  }

  // --- Library Topic Subscriptions ---

  String _formatTopicName(String mangaId) {
    final sanitized = mangaId.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9-_.~%]'),
      '_',
    );
    return 'manga_$sanitized';
  }

  Future<void> subscribeToMangaTopic(String mangaId) async {
    if (!isSupported || _messaging == null || mangaId.isEmpty) return;

    final topic = _formatTopicName(mangaId);
    try {
      await _messaging!.subscribeToTopic(topic);
      final prefs = await SharedPreferences.getInstance();
      final subscribed = prefs.getStringList(_subscribedTopicsKey) ?? [];
      if (!subscribed.contains(mangaId)) {
        subscribed.add(mangaId);
        await prefs.setStringList(_subscribedTopicsKey, subscribed);
      }
      debugPrint('Subscribed to FCM topic: $topic');
    } catch (e) {
      debugPrint('Failed to subscribe to FCM topic "$topic": $e');
    }
  }

  Future<void> unsubscribeFromMangaTopic(String mangaId) async {
    if (!isSupported || _messaging == null || mangaId.isEmpty) return;

    final topic = _formatTopicName(mangaId);
    try {
      await _messaging!.unsubscribeFromTopic(topic);
      final prefs = await SharedPreferences.getInstance();
      final subscribed = prefs.getStringList(_subscribedTopicsKey) ?? [];
      if (subscribed.contains(mangaId)) {
        subscribed.remove(mangaId);
        await prefs.setStringList(_subscribedTopicsKey, subscribed);
      }
      debugPrint('Unsubscribed from FCM topic: $topic');
    } catch (e) {
      debugPrint('Failed to unsubscribe from FCM topic "$topic": $e');
    }
  }

  Future<void> syncLibraryTopics(List<String> currentLibraryMangaIds) async {
    if (!isSupported || _messaging == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final previouslySubscribed =
          prefs.getStringList(_subscribedTopicsKey) ?? [];

      // Unsubscribe from topics that are no longer in the user's library
      final toRemove = previouslySubscribed
          .where((id) => !currentLibraryMangaIds.contains(id))
          .toList();
      for (final id in toRemove) {
        await unsubscribeFromMangaTopic(id);
      }

      // Subscribe to all current library mangas
      for (final id in currentLibraryMangaIds) {
        await subscribeToMangaTopic(id);
      }

      await prefs.setStringList(_subscribedTopicsKey, currentLibraryMangaIds);
      debugPrint(
        'FCM Library topics synchronized. Total: ${currentLibraryMangaIds.length}',
      );
    } catch (e) {
      debugPrint('Error syncing FCM library topics: $e');
    }
  }

  Future<void> clearAllSubscribedTopics() async {
    if (!isSupported || _messaging == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final subscribed = prefs.getStringList(_subscribedTopicsKey) ?? [];
      await prefs.remove(_subscribedTopicsKey);

      if (subscribed.isNotEmpty) {
        for (final id in subscribed) {
          final topic = _formatTopicName(id);
          try {
            await _messaging!.unsubscribeFromTopic(topic);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error clearing FCM topics: $e');
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _messageOpenedAppSubscription?.cancel();
  }
}
