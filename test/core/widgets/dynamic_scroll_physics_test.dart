import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/core/widgets/dynamic_scroll_physics.dart';

void main() {
  group('ReaderScrollPhysics Flutter 3.50 shouldUpdate Tests', () {
    test('shouldUpdate returns true when isZoomed changes', () {
      const physics1 = ReaderScrollPhysics(isZoomed: false);
      const physics2 = ReaderScrollPhysics(isZoomed: true);

      expect(physics2.shouldUpdate(physics1), isTrue);
      expect(physics1.shouldUpdate(physics2), isTrue);
    });

    test('shouldUpdate returns true when decelerationRate changes', () {
      const physics1 = ReaderScrollPhysics(
        decelerationRate: ScrollDecelerationRate.normal,
      );
      const physics2 = ReaderScrollPhysics(
        decelerationRate: ScrollDecelerationRate.fast,
      );

      expect(physics2.shouldUpdate(physics1), isTrue);
    });

    test('shouldUpdate returns true when enableOverscroll changes', () {
      const physics1 = ReaderScrollPhysics(enableOverscroll: true);
      const physics2 = ReaderScrollPhysics(enableOverscroll: false);

      expect(physics2.shouldUpdate(physics1), isTrue);
    });

    test('shouldUpdate returns false when identical or same properties', () {
      const physics1 = ReaderScrollPhysics(
        isZoomed: false,
        decelerationRate: ScrollDecelerationRate.normal,
        enableOverscroll: true,
      );
      const physics2 = ReaderScrollPhysics(
        isZoomed: false,
        decelerationRate: ScrollDecelerationRate.normal,
        enableOverscroll: true,
      );

      expect(physics1.shouldUpdate(physics1), isFalse);
      expect(physics2.shouldUpdate(physics1), isFalse);
    });

    test('applyTo preserves configuration properties', () {
      const physics = ReaderScrollPhysics(
        isZoomed: true,
        decelerationRate: ScrollDecelerationRate.fast,
        enableOverscroll: false,
      );
      final applied = physics.applyTo(const ClampingScrollPhysics());

      expect(applied.isZoomed, isTrue);
      expect(applied.decelerationRate, equals(ScrollDecelerationRate.fast));
      expect(applied.enableOverscroll, isFalse);
      expect(applied.parent, isA<ClampingScrollPhysics>());
    });

    test('isZoomed locks scrolling offset and ballistic simulation', () {
      const zoomedPhysics = ReaderScrollPhysics(isZoomed: true);
      const normalPhysics = ReaderScrollPhysics(isZoomed: false);

      final dummyMetrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 500,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );

      expect(zoomedPhysics.applyPhysicsToUserOffset(dummyMetrics, 50.0), equals(0.0));
      expect(normalPhysics.applyPhysicsToUserOffset(dummyMetrics, 50.0), equals(50.0));
      expect(zoomedPhysics.createBallisticSimulation(dummyMetrics, 200.0), isNull);
    });
  });

  group('DynamicConfigScrollPhysics Tests', () {
    test('shouldUpdate detects locked state, deceleration rate and friction changes', () {
      const physics1 = DynamicConfigScrollPhysics(
        isLocked: false,
        frictionMultiplier: 1.0,
      );
      const physicsLocked = DynamicConfigScrollPhysics(
        isLocked: true,
        frictionMultiplier: 1.0,
      );
      const physicsFriction = DynamicConfigScrollPhysics(
        isLocked: false,
        frictionMultiplier: 0.5,
      );

      expect(physicsLocked.shouldUpdate(physics1), isTrue);
      expect(physicsFriction.shouldUpdate(physics1), isTrue);
      expect(physics1.shouldUpdate(physics1), isFalse);
    });

    test('applyPhysicsToUserOffset respects frictionMultiplier and isLocked', () {
      const locked = DynamicConfigScrollPhysics(isLocked: true);
      const halfFriction = DynamicConfigScrollPhysics(frictionMultiplier: 0.5);

      final dummyMetrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1000,
        pixels: 100,
        viewportDimension: 500,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );

      expect(locked.applyPhysicsToUserOffset(dummyMetrics, 40.0), equals(0.0));
      expect(halfFriction.applyPhysicsToUserOffset(dummyMetrics, 40.0), equals(20.0));
    });
  });
}
