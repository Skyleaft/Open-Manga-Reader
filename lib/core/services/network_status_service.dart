import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkStatusService {
  final Connectivity _connectivity;
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _periodicCheckTimer;

  bool get isOnline => isOnlineNotifier.value;

  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  NetworkStatusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<void> init() async {
    // Initial check
    await checkConnectivity();

    // Listen for hardware connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) async {
      await _handleConnectivityResults(results);
    });

    // Periodic heartbeat check every 30 seconds
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return await _handleConnectivityResults(results);
    } catch (_) {
      return isOnline;
    }
  }

  Future<bool> _handleConnectivityResults(
    List<ConnectivityResult> results,
  ) async {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      _updateStatus(false);
      return false;
    }

    // Hardware reports connected, verify reachability
    final reachable = await _verifyReachability();
    _updateStatus(reachable);
    return reachable;
  }

  Future<bool> _verifyReachability() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        return fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void reportNetworkError() {
    if (isOnline) {
      _updateStatus(false);
    }
  }

  void reportNetworkSuccess() {
    if (!isOnline) {
      _updateStatus(true);
    }
  }

  void _updateStatus(bool newStatus) {
    if (isOnlineNotifier.value != newStatus) {
      isOnlineNotifier.value = newStatus;
      _statusController.add(newStatus);
      debugPrint(
        '🌐 [NetworkStatusService] Status changed: ${newStatus ? "ONLINE" : "OFFLINE"}',
      );
    }
  }

  void dispose() {
    _subscription?.cancel();
    _periodicCheckTimer?.cancel();
    _statusController.close();
    isOnlineNotifier.dispose();
  }
}
