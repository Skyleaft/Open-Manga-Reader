import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/legacy.dart';

class WindowService with WindowListener {
  static const String _keyWidth = 'window_width';
  static const String _keyHeight = 'window_height';
  static const String _keyPosX = 'window_pos_x';
  static const String _keyPosY = 'window_pos_y';
  static const String _keyIsMaximized = 'window_is_maximized';

  Timer? _windowSaveDebounce;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> init() async {
    if (!isDesktop) return;

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);

      final prefs = await SharedPreferences.getInstance();
      final width = prefs.getDouble(_keyWidth);
      final height = prefs.getDouble(_keyHeight);
      final posX = prefs.getDouble(_keyPosX);
      final posY = prefs.getDouble(_keyPosY);
      final isMaximized = prefs.getBool(_keyIsMaximized) ?? false;

      final hasCustomSize =
          width != null && height != null && width > 0 && height > 0;
      final hasCustomPos = posX != null && posY != null;

      final windowOptions = WindowOptions(
        size: hasCustomSize ? Size(width, height) : const Size(1280, 720),
        minimumSize: const Size(480, 640),
        center: !hasCustomPos,
        title: 'Open Manga Reader',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (hasCustomPos) {
          await windowManager.setPosition(Offset(posX, posY));
        }
        if (isMaximized) {
          await windowManager.maximize();
        }
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (e) {
      debugPrint('Error restoring window state: $e');
    }
  }

  Future<bool> isFullScreen() async {
    if (!isDesktop) return false;
    try {
      return await windowManager.isFullScreen();
    } catch (e) {
      debugPrint('Window manager full screen check error: $e');
      return false;
    }
  }

  Future<void> setFullScreen(bool isFullScreen) async {
    if (!isDesktop) return;
    try {
      await windowManager.setFullScreen(isFullScreen);
    } catch (e) {
      debugPrint('Window manager set full screen error: $e');
    }
  }

  @override
  void onWindowResized() {
    _debounceSaveWindowState();
  }

  @override
  void onWindowMoved() {
    _debounceSaveWindowState();
  }

  @override
  void onWindowMaximize() {
    _debounceSaveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _debounceSaveWindowState();
  }

  void _debounceSaveWindowState() {
    _windowSaveDebounce?.cancel();
    _windowSaveDebounce = Timer(const Duration(milliseconds: 300), () {
      saveWindowState();
    });
  }

  Future<void> saveWindowState() async {
    if (!isDesktop) return;
    try {
      final isMaximized = await windowManager.isMaximized();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsMaximized, isMaximized);

      if (!isMaximized) {
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();
        await prefs.setDouble(_keyWidth, size.width);
        await prefs.setDouble(_keyHeight, size.height);
        await prefs.setDouble(_keyPosX, position.dx);
        await prefs.setDouble(_keyPosY, position.dy);
      }
    } catch (e) {
      debugPrint('Error saving window state: $e');
    }
  }
}
