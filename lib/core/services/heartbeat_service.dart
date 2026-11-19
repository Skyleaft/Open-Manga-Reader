import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../di/injection.dart';
import '../network/manga_api_service.dart';

class HeartbeatService with WidgetsBindingObserver {
  Timer? _heartbeatTimer;
  StreamSubscription<User?>? _authSubscription;
  bool _isObserverAdded = false;

  void init() {
    if (!_isObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverAdded = true;
    }

    try {
      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          start();
        } else {
          stop();
        }
      });

      if (FirebaseAuth.instance.currentUser != null) {
        start();
      }
    } catch (e) {
      debugPrint('HeartbeatService auth listener warning/error: $e');
    }
  }

  void start() {
    _stopTimer();
    sendHeartbeat();
    _startTimer();
  }

  void stop() {
    _stopTimer();
  }

  void _startTimer() {
    _stopTimer();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      sendHeartbeat();
    });
  }

  void _stopTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> sendHeartbeat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final apiService = getIt<MangaApiService>();
        if (apiService.jwtToken != null) {
          await apiService.patchUserHeartbeat();
        }
      } catch (e) {
        debugPrint('Failed to send heartbeat: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (state == AppLifecycleState.resumed) {
      sendHeartbeat();
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    }
  }

  void dispose() {
    if (_isObserverAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverAdded = false;
    }
    _stopTimer();
    _authSubscription?.cancel();
    _authSubscription = null;
  }
}
