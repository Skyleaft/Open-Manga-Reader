import 'package:flutter/widgets.dart';

/// Flutter 3.50 Dynamic Scroll Physics implementation using [ScrollPhysics.shouldUpdate].
///
/// This physics allows apps to dynamically reconfigure reader scroll behavior
/// (such as zoom/pan lock, deceleration rate, and overscroll bouncing) when
/// configuration settings change, without rebuilding or discarding the underlying
/// [ScrollPosition].
class ReaderScrollPhysics extends ScrollPhysics {
  /// Whether the reader view is currently zoomed in, requiring vertical
  /// scrolling to yield to interactive pan gestures.
  final bool isZoomed;

  /// Custom deceleration rate for reader flick gestures.
  final ScrollDecelerationRate decelerationRate;

  /// Whether overscroll bounces at the edges.
  final bool enableOverscroll;

  const ReaderScrollPhysics({
    super.parent,
    this.isZoomed = false,
    this.decelerationRate = ScrollDecelerationRate.normal,
    this.enableOverscroll = true,
  });

  @override
  ReaderScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReaderScrollPhysics(
      parent: buildParent(ancestor),
      isZoomed: isZoomed,
      decelerationRate: decelerationRate,
      enableOverscroll: enableOverscroll,
    );
  }

  /// Flutter 3.50 API: Updates scroll behavior dynamically when configuration changes.
  @override
  bool shouldUpdate(covariant ReaderScrollPhysics old) {
    if (isZoomed != old.isZoomed ||
        decelerationRate != old.decelerationRate ||
        enableOverscroll != old.enableOverscroll) {
      return true;
    }
    return super.shouldUpdate(old);
  }

  @override
  bool get allowImplicitScrolling => !isZoomed;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isZoomed) {
      return 0.0;
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (isZoomed) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

/// A dynamic configurable [ScrollPhysics] that leverages Flutter 3.50's [shouldUpdate]
/// callback to react to runtime setting changes (e.g., locking scrolling, tuning friction,
/// or adjusting deceleration rates).
class DynamicConfigScrollPhysics extends ScrollPhysics {
  /// Whether scrolling interaction is locked.
  final bool isLocked;

  /// The deceleration rate applied when ballistic scrolling occurs.
  final ScrollDecelerationRate decelerationRate;

  /// Friction multiplier applied to user drag offsets.
  final double frictionMultiplier;

  const DynamicConfigScrollPhysics({
    super.parent,
    this.isLocked = false,
    this.decelerationRate = ScrollDecelerationRate.normal,
    this.frictionMultiplier = 1.0,
  });

  @override
  DynamicConfigScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return DynamicConfigScrollPhysics(
      parent: buildParent(ancestor),
      isLocked: isLocked,
      decelerationRate: decelerationRate,
      frictionMultiplier: frictionMultiplier,
    );
  }

  /// Flutter 3.50 API: Returns true if configuration settings have changed.
  @override
  bool shouldUpdate(covariant DynamicConfigScrollPhysics old) {
    if (isLocked != old.isLocked ||
        decelerationRate != old.decelerationRate ||
        frictionMultiplier != old.frictionMultiplier) {
      return true;
    }
    return super.shouldUpdate(old);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isLocked) {
      return 0.0;
    }
    if (frictionMultiplier != 1.0) {
      return super.applyPhysicsToUserOffset(
        position,
        offset * frictionMultiplier,
      );
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (isLocked) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
