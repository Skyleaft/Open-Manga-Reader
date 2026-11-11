import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_manga_reader/core/services/haptic_service.dart';
import 'package:my_manga_reader/features/settings/presentation/widgets/haptic_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HapticSettingsBottomSheet renders correctly and toggles switch',
      (tester) async {
    await AppHaptics.init();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HapticSettingsBottomSheet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Enable Haptic Feedback'), findsOneWidget);
    expect(find.text('TACTILE PLAYGROUND'), findsOneWidget);
    expect(find.text('Light Tap'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);

    // Tap Light Tap chip
    await tester.tap(find.text('Light Tap'));
    await tester.pumpAndSettle();

    // Toggle switch off
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(AppHaptics.isEnabled, isFalse);
    expect(find.text('Haptics disabled'), findsNothing);
    expect(find.text('TACTILE PLAYGROUND'), findsNothing);
  });
}
