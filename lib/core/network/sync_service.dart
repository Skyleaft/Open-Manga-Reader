import 'dart:convert';
import '../di/injection.dart';
import '../storage/hive_storage.dart';
import 'manga_api_service.dart';

class SyncAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  SyncAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncAction.fromMap(Map<String, dynamic> map) {
    return SyncAction(
      id: map['id'] as String,
      type: map['type'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => jsonEncode(toMap());
}

class SyncService {
  bool _isSyncing = false;

  Future<void> enqueueAction(String type, Map<String, dynamic> payload) async {
    final action = SyncAction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await HiveStorage.syncQueueBox.put(action.id, action.toJson());
  }

  /// Returns a set of manga IDs that currently have pending offline actions of [type].
  Set<String> getPendingMangaIdsForType(String type) {
    final ids = <String>{};
    try {
      final box = HiveStorage.syncQueueBox;
      for (final value in box.values) {
        if (value is String) {
          try {
            final map = jsonDecode(value) as Map<String, dynamic>;
            if (map['type'] == type) {
              final payload = map['payload'] as Map<String, dynamic>?;
              final mangaId = payload?['mangaId'] as String? ?? payload?['id'] as String?;
              if (mangaId != null && mangaId.isNotEmpty) {
                ids.add(mangaId);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return ids;
  }

  Future<void> syncPendingActions() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final box = HiveStorage.syncQueueBox;
      if (box.isEmpty) return;

      final apiService = getIt<MangaApiService>();
      final entries = box.toMap().entries.toList();

      // Coalesce progression_update entries: only keep the newest update per mangaId
      final Map<String, dynamic> newestProgressionKey = {};
      final List<dynamic> obsoleteKeys = [];

      for (final entry in entries) {
        try {
          final action = SyncAction.fromMap(jsonDecode(entry.value as String));
          if (action.type == 'progression_update') {
            final mangaId = action.payload['mangaId']?.toString();
            if (mangaId != null && mangaId.isNotEmpty) {
              if (newestProgressionKey.containsKey(mangaId)) {
                // An older entry exists, mark it for removal
                obsoleteKeys.add(newestProgressionKey[mangaId]);
              }
              newestProgressionKey[mangaId] = entry.key;
            }
          }
        } catch (_) {}
      }

      for (final oldKey in obsoleteKeys) {
        await box.delete(oldKey);
      }

      for (final entry in entries) {
        final key = entry.key;
        if (obsoleteKeys.contains(key)) continue;

        final actionJson = entry.value as String;
        SyncAction action;
        try {
          action = SyncAction.fromMap(jsonDecode(actionJson));
        } catch (_) {
          // Corrupted entry, remove it
          await box.delete(key);
          continue;
        }

        bool success = false;
        try {
          switch (action.type) {
            case 'library_add':
              await apiService.addToUserLibrary(action.payload);
              success = true;
              break;
            case 'library_remove':
              await apiService.removeFromUserLibrary(action.payload['mangaId']);
              success = true;
              break;
            case 'progression_update':
              await apiService.updateUserProgression(action.payload);
              success = true;
              break;
          }
        } catch (_) {
          success = false;
        }

        if (success) {
          await box.delete(key);
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
