import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiveStorage {
  static const String syncQueueBoxName = 'sync_queue';
  static const String mangaDetailBoxName = 'manga_detail_cache';
  static const String libraryBoxName = 'manga_library';
  static const String progressionBoxName = 'manga_progression';
  static const String downloadsBoxName = 'downloaded_chapters';

  static const String _migratedKey = 'migrated_to_hive_v1';

  static Box<dynamic> get syncQueueBox => Hive.box(syncQueueBoxName);
  static Box<dynamic> get mangaDetailBox => Hive.box(mangaDetailBoxName);
  static Box<dynamic> get libraryBox => Hive.box(libraryBoxName);
  static Box<dynamic> get progressionBox => Hive.box(progressionBoxName);
  static Box<dynamic> get downloadsBox => Hive.box(downloadsBoxName);

  /// Initializes Hive for Flutter and opens all persistent boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox(syncQueueBoxName),
      Hive.openBox(mangaDetailBoxName),
      Hive.openBox(libraryBoxName),
      Hive.openBox(progressionBoxName),
      Hive.openBox(downloadsBoxName),
    ]);
  }

  /// One-time migration of large data sets from SharedPreferences to Hive.
  /// After migration, removes those large entries from SharedPreferences so that
  /// `shared_preferences.json` shrinks from tens of megabytes down to just a few kilobytes.
  static Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMigrated = prefs.getBool(_migratedKey) ?? false;
      if (isMigrated) {
        return;
      }

      debugPrint('[HiveStorage] Starting one-time migration from SharedPreferences to Hive...');

      // 1. Migrate Sync Queue
      final syncList = prefs.getStringList('sync_queue');
      if (syncList != null && syncList.isNotEmpty) {
        for (final item in syncList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final id = map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
            await syncQueueBox.put(id, item);
          } catch (_) {
            await syncQueueBox.add(item);
          }
        }
      }
      await prefs.remove('sync_queue');

      // 2. Migrate Manga Library
      final libraryList = prefs.getStringList('manga_library');
      if (libraryList != null && libraryList.isNotEmpty) {
        for (final item in libraryList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final id = map['id']?.toString() ?? map['mangaId']?.toString();
            if (id != null) {
              await libraryBox.put(id, item);
            }
          } catch (_) {}
        }
      }
      await prefs.remove('manga_library');

      // 3. Migrate Manga Progression
      final progressionList = prefs.getStringList('manga_progression');
      if (progressionList != null && progressionList.isNotEmpty) {
        for (final item in progressionList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final id = map['mangaId']?.toString() ?? map['id']?.toString();
            if (id != null) {
              await progressionBox.put(id, item);
            }
          } catch (_) {}
        }
      }
      await prefs.remove('manga_progression');

      // 4. Migrate Manga Detail Cache
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (key.startsWith('manga_detail_') && !key.startsWith('manga_detail_time_')) {
          final mangaId = key.substring('manga_detail_'.length);
          final detailJson = prefs.getString(key);
          final timestamp = prefs.getInt('manga_detail_time_$mangaId') ?? DateTime.now().millisecondsSinceEpoch;
          if (detailJson != null) {
            await mangaDetailBox.put(mangaId, {
              'json': detailJson,
              'timestamp': timestamp,
            });
          }
          await prefs.remove(key);
          await prefs.remove('manga_detail_time_$mangaId');
        }
      }

      await prefs.setBool(_migratedKey, true);
      debugPrint('[HiveStorage] Migration completed successfully. SharedPreferences trimmed.');
    } catch (e, stack) {
      debugPrint('[HiveStorage] Error during migration: $e\n$stack');
    }
  }
}
