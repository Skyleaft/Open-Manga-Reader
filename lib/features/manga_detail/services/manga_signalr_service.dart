import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../core/network/sync_service.dart';
import '../models/chapter_scraping_progress.dart';

class MangaSignalRService {
  HubConnection? _hubConnection;
  String? _currentBaseUrl;
  final Set<String> _joinedMangaGroups = {};
  final Set<String> _joinedUserGroups = {};

  final _scrapingProgressController =
      StreamController<ChapterScrapingProgress>.broadcast();
  final _chaptersUpdatedController =
      StreamController<ChaptersUpdatedEvent>.broadcast();
  final _progressionUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChapterScrapingProgress> get scrapingProgressStream =>
      _scrapingProgressController.stream;
  Stream<ChaptersUpdatedEvent> get chaptersUpdatedStream =>
      _chaptersUpdatedController.stream;
  Stream<Map<String, dynamic>> get progressionUpdatedStream =>
      _progressionUpdatedController.stream;

  bool get isConnected =>
      _hubConnection?.state == HubConnectionState.Connected;

  Future<void> init() async {
    await _ensureConnection();
  }

  Future<void> disconnect() async {
    if (_hubConnection != null &&
        _hubConnection!.state != HubConnectionState.Disconnected) {
      try {
        await _hubConnection!.stop();
        debugPrint('SignalR Hub disconnected manually');
      } catch (e) {
        debugPrint('Failed to disconnect SignalR Hub: $e');
      }
    }
  }

  Future<void> _ensureConnection() async {
    final baseUrl = AppConfig.baseUrl;

    if (_hubConnection != null && _currentBaseUrl == baseUrl) {
      if (_hubConnection!.state == HubConnectionState.Disconnected) {
        try {
          await _hubConnection!.start();
          debugPrint('SignalR Hub restarted');
          for (final id in _joinedMangaGroups) {
            try {
              await _hubConnection!.invoke('JoinMangaGroup', args: [id]);
              debugPrint('SignalR: Re-joined manga group "$id"');
            } catch (e) {
              debugPrint('SignalR: Error re-joining manga group "$id": $e');
            }
          }
          for (final userId in _joinedUserGroups) {
            try {
              await _hubConnection!.invoke('JoinUserGroup', args: [userId]);
              debugPrint('SignalR: Re-joined user group "$userId"');
            } catch (e) {
              debugPrint('SignalR: Error re-joining user group "$userId": $e');
            }
          }
        } catch (e) {
          debugPrint('Failed to restart SignalR Hub connection: $e');
        }
      }
      return;
    }

    // If BaseUrl changed or first time init
    if (_hubConnection != null) {
      try {
        await _hubConnection!.stop();
      } catch (_) {}
      _hubConnection = null;
    }

    _currentBaseUrl = baseUrl;
    final hubUrl = '$baseUrl/hubs/manga';

    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async {
                try {
                  final apiService = getIt<MangaApiService>();
                  return apiService.jwtToken ?? '';
                } catch (_) {
                  return '';
                }
              },
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.on('ChapterScrapingProgress', _onChapterScrapingProgress);
      _hubConnection!.on('ChaptersUpdated', _onChaptersUpdated);
      _hubConnection!.on('UserProgressionUpdated', _onUserProgressionUpdated);

      _hubConnection!.onclose(({error}) {
        debugPrint('SignalR Hub closed. Error: $error');
      });

      _hubConnection!.onreconnecting(({error}) {
        debugPrint('SignalR Hub reconnecting... Error: $error');
      });

      _hubConnection!.onreconnected(({connectionId}) async {
        debugPrint('SignalR Hub reconnected. ConnectionId: $connectionId');
        for (final id in _joinedMangaGroups) {
          try {
            await _hubConnection!.invoke('JoinMangaGroup', args: [id]);
            debugPrint('SignalR: Re-joined manga group "$id"');
          } catch (e) {
            debugPrint('SignalR: Error re-joining manga group "$id": $e');
          }
        }
        for (final userId in _joinedUserGroups) {
          try {
            await _hubConnection!.invoke('JoinUserGroup', args: [userId]);
            debugPrint('SignalR: Re-joined user group "$userId"');
          } catch (e) {
            debugPrint('SignalR: Error re-joining user group "$userId": $e');
          }
        }
        // Auto flush any pending offline actions once connection is back
        try {
          getIt<SyncService>().syncPendingActions();
        } catch (_) {}
      });

      await _hubConnection!.start();
      debugPrint('SignalR Hub connected to $hubUrl');
    } catch (e) {
      debugPrint('Failed to connect to SignalR Hub at $hubUrl: $e');
    }
  }

  void _onChapterScrapingProgress(List<dynamic>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    try {
      final raw = arguments[0];
      if (raw is Map<String, dynamic>) {
        final progress = ChapterScrapingProgress.fromMap(raw);
        _scrapingProgressController.add(progress);
      } else if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final progress = ChapterScrapingProgress.fromMap(map);
        _scrapingProgressController.add(progress);
      }
    } catch (e) {
      debugPrint('Error parsing ChapterScrapingProgress SignalR event: $e');
    }
  }

  void _onChaptersUpdated(List<dynamic>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    try {
      final raw = arguments[0];
      if (raw is Map<String, dynamic>) {
        final event = ChaptersUpdatedEvent.fromMap(raw);
        _chaptersUpdatedController.add(event);
      } else if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        final event = ChaptersUpdatedEvent.fromMap(map);
        _chaptersUpdatedController.add(event);
      }
    } catch (e) {
      debugPrint('Error parsing ChaptersUpdated SignalR event: $e');
    }
  }

  void _onUserProgressionUpdated(List<dynamic>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    try {
      final raw = arguments[0];
      if (raw is Map<String, dynamic>) {
        _progressionUpdatedController.add(raw);
      } else if (raw is Map) {
        _progressionUpdatedController.add(Map<String, dynamic>.from(raw));
      }
    } catch (e) {
      debugPrint('Error parsing UserProgressionUpdated SignalR event: $e');
    }
  }

  Future<void> joinUserGroup(String userId) async {
    if (userId.isEmpty) return;
    _joinedUserGroups.add(userId);
    await _ensureConnection();

    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke('JoinUserGroup', args: [userId]);
        debugPrint('SignalR: Joined user group "$userId"');
      } catch (e) {
        debugPrint('SignalR: Error joining user group "$userId": $e');
      }
    }
  }

  Future<void> leaveUserGroup(String userId) async {
    if (userId.isEmpty) return;
    _joinedUserGroups.remove(userId);

    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke('LeaveUserGroup', args: [userId]);
        debugPrint('SignalR: Left user group "$userId"');
      } catch (e) {
        if (_hubConnection?.state != HubConnectionState.Connected ||
            e.toString().toLowerCase().contains('canceled')) {
          return;
        }
        debugPrint('SignalR: Error leaving user group "$userId": $e');
      }
    }
  }

  Future<void> joinMangaGroup(String mangaId) async {
    if (mangaId.isEmpty) return;
    _joinedMangaGroups.add(mangaId);
    await _ensureConnection();

    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke('JoinMangaGroup', args: [mangaId]);
        debugPrint('SignalR: Joined manga group "$mangaId"');
      } catch (e) {
        debugPrint('SignalR: Error joining manga group "$mangaId": $e');
      }
    }
  }

  Future<void> leaveMangaGroup(String mangaId) async {
    if (mangaId.isEmpty) return;
    _joinedMangaGroups.remove(mangaId);

    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke('LeaveMangaGroup', args: [mangaId]);
        debugPrint('SignalR: Left manga group "$mangaId"');
      } catch (e) {
        if (_hubConnection?.state != HubConnectionState.Connected ||
            e.toString().toLowerCase().contains('canceled')) {
          return;
        }
        debugPrint('SignalR: Error leaving manga group "$mangaId": $e');
      }
    }
  }

  Future<void> leaveMangaGroupAndDisconnect(String mangaId) async {
    await leaveMangaGroup(mangaId);
    if (_joinedMangaGroups.isEmpty && _joinedUserGroups.isEmpty) {
      await disconnect();
    }
  }

  void dispose() {
    _joinedMangaGroups.clear();
    _joinedUserGroups.clear();
    _scrapingProgressController.close();
    _chaptersUpdatedController.close();
    _progressionUpdatedController.close();
    _hubConnection?.stop();
    _hubConnection = null;
  }
}
