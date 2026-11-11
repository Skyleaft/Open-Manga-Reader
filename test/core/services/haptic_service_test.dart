import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_manga_reader/core/services/haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppHaptics Tests', () {
    test('init sets enabled status and handles defaults correctly', () async {
      await AppHaptics.init();
      expect(AppHaptics.isEnabled, isTrue);
    });

    test('setEnabled persists preference and toggles state', () async {
      await AppHaptics.setEnabled(false);
      expect(AppHaptics.isEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app_haptics_enabled'), isFalse);

      await AppHaptics.setEnabled(true);
      expect(AppHaptics.isEnabled, isTrue);
      expect(prefs.getBool('app_haptics_enabled'), isTrue);
    });

    test('all haptic methods complete without unhandled exceptions', () async {
      await AppHaptics.selection();
      await AppHaptics.lightImpact();
      await AppHaptics.mediumImpact();
      await AppHaptics.heavyImpact();
      await AppHaptics.vibrate();

      await AppHaptics.success();
      await AppHaptics.warning();
      await AppHaptics.error();

      await AppHaptics.toggle(true);
      await AppHaptics.toggle(false);

      await AppHaptics.favorite(true);
      await AppHaptics.favorite(false);

      await AppHaptics.pullToRefresh();
      await AppHaptics.pageTurn();
      await AppHaptics.dragStart();
      await AppHaptics.segmentTick();
      await AppHaptics.segmentFrequentTick();
      await AppHaptics.gestureThresholdActivate();
      await AppHaptics.gestureThresholdDeactivate();
      await AppHaptics.gestureEnd();
      await AppHaptics.longPress();
    });
  });
}
