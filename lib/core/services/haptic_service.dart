import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:haptic_kit/haptic_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:haptic_kit/haptic_kit.dart';

/// Centralized service for rich and interactive haptic feedback powered by `haptic_kit`.
///
/// Provides graceful degradation across platforms (Android, iOS, Desktop, Web)
/// and seamlessly integrates with persistent user preferences.
class AppHaptics {
  static const String _prefKey = 'app_haptics_enabled';
  static bool _initialized = false;
  static bool _enabled = true;

  /// Whether haptic feedback is currently enabled by user preference.
  static bool get isEnabled => _enabled;

  /// Whether the current platform natively supports haptic engine.
  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Initialize haptics setting from SharedPreferences and pre-warm generators.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
      HapticSettings.enabled = _enabled && isPlatformSupported;
      if (isPlatformSupported && _enabled) {
        await Haptics.prepare().catchError((_) => false);
      }
    } catch (e) {
      debugPrint('[AppHaptics] Error initializing haptics: $e');
    } finally {
      _initialized = true;
    }
  }

  /// Toggle haptics setting and persist to SharedPreferences.
  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    HapticSettings.enabled = enabled && isPlatformSupported;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
      if (enabled) {
        await selection();
      }
    } catch (e) {
      debugPrint('[AppHaptics] Error saving preference: $e');
    }
  }

  /// Safe execution wrapper preventing unhandled platform exceptions on unsupported environments.
  static Future<void> _safeRun(Future<void> Function() action) async {
    if (!_enabled || !isPlatformSupported) return;
    try {
      await action();
    } catch (_) {
      // Gracefully ignore missing plugin or platform mismatch
    }
  }

  // ==========================================
  // Standard replacements for Flutter HapticFeedback
  // ==========================================

  /// Replaces `HapticFeedback.selectionClick()` with crisp selection tap.
  static Future<void> selection() => _safeRun(() => Haptics.selection());

  /// Replaces `HapticFeedback.lightImpact()` with subtle tactile impact.
  static Future<void> lightImpact() =>
      _safeRun(() => Haptics.impact(HapticImpactStyle.light));

  /// Replaces `HapticFeedback.mediumImpact()` with standard tactile impact.
  static Future<void> mediumImpact() =>
      _safeRun(() => Haptics.impact(HapticImpactStyle.medium));

  /// Replaces `HapticFeedback.heavyImpact()` with pronounced tactile impact.
  static Future<void> heavyImpact() =>
      _safeRun(() => Haptics.impact(HapticImpactStyle.heavy));

  /// Replaces `HapticFeedback.vibrate()`.
  static Future<void> vibrate() => _safeRun(
        () => Vibration.vibrate(duration: const Duration(milliseconds: 150)),
      );

  // ==========================================
  // Semantic & Interactive Feedback
  // ==========================================

  /// Confirms a successful action (e.g. finished download, save bookmark, clear cache).
  static Future<void> success() =>
      _safeRun(() => Haptics.notification(HapticNotificationStyle.success));

  /// Warns user about a non-fatal event or action requiring caution (e.g. clear cache prompt).
  static Future<void> warning() =>
      _safeRun(() => Haptics.notification(HapticNotificationStyle.warning));

  /// Signals an error or failed action (e.g. network failure, invalid input).
  static Future<void> error() =>
      _safeRun(() => Haptics.notification(HapticNotificationStyle.error));

  /// Interactive switch / checkbox toggle feedback.
  static Future<void> toggle(bool value) => _safeRun(
        () => Haptics.semantic(
          value ? SemanticHaptic.toggleOn : SemanticHaptic.toggleOff,
        ),
      );

  /// Native platform semantic haptic feedback.
  static Future<void> semantic(SemanticHaptic type) =>
      _safeRun(() => Haptics.semantic(type));

  /// Interactive favorite button tap with satisfying tactile feedback.
  static Future<void> favorite(bool isFavorite) => _safeRun(() {
        if (isFavorite) {
          return Haptics.semantic(SemanticHaptic.confirm);
        } else {
          return Haptics.semantic(SemanticHaptic.toggleOff);
        }
      });

  /// Pull-to-refresh pull threshold milestone feedback.
  static Future<void> pullToRefresh() =>
      _safeRun(() => Haptics.impact(HapticImpactStyle.medium));

  /// Slider scrubbing or reader page slider drag start.
  static Future<void> dragStart() =>
      _safeRun(() => Haptics.semantic(SemanticHaptic.dragStart));

  /// Continuous slider tick when scrubbing fast through chapters or pages.
  static Future<void> segmentFrequentTick() =>
      _safeRun(() => Haptics.semantic(SemanticHaptic.segmentFrequentTick));

  /// Discrete detent tick (e.g. overscroll milestone or coarse slider steps).
  static Future<void> segmentTick() =>
      _safeRun(() => Haptics.semantic(SemanticHaptic.segmentTick));

  /// Reader pull-to-next threshold armed/activated.
  static Future<void> gestureThresholdActivate() => _safeRun(
        () => Haptics.semantic(SemanticHaptic.gestureThresholdActivate),
      );

  /// Reader pull-to-next threshold cancelled/deactivated.
  static Future<void> gestureThresholdDeactivate() => _safeRun(
        () => Haptics.semantic(SemanticHaptic.gestureThresholdDeactivate),
      );

  /// Drag or gesture finished.
  static Future<void> gestureEnd() =>
      _safeRun(() => Haptics.semantic(SemanticHaptic.gestureEnd));

  /// Long press recognition feedback.
  static Future<void> longPress() =>
      _safeRun(() => Haptics.semantic(SemanticHaptic.longPress));

  /// Reader page turn tactile tick (giving real book page-turn sensation).
  static Future<void> pageTurn() =>
      _safeRun(() => Haptics.impact(HapticImpactStyle.light));
}
