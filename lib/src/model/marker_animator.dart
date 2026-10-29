import 'package:flutter/animation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Settings for animating markers that move.
class MarkerAnimation {
  /// Creates animation settings. A zero [duration] disables animation.
  const MarkerAnimation({
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeInOut,
  });

  /// No animation: markers jump.
  static const MarkerAnimation none = MarkerAnimation(duration: Duration.zero);

  /// How long a move takes.
  final Duration duration;

  /// Easing of a move.
  final Curve curve;
}

class _Tween {
  _Tween(this.from, this.to, this.total, this.curve);
  final LatLng from;
  final LatLng to;
  final Duration total;
  final Curve curve;
  Duration elapsed = Duration.zero;

  double get t => total == Duration.zero
      ? 1
      : (elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

  LatLng get value {
    final e = curve.transform(t);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * e,
      from.longitude + (to.longitude - from.longitude) * e,
    );
  }
}

/// Interpolates marker positions over time. Pure and clock-free: feed it the
/// time that passed with [advance], so it is testable without a ticker.
class MarkerAnimator {
  final Map<String, _Tween> _tweens = {};

  /// Whether any marker is still moving.
  bool get isAnimating => _tweens.isNotEmpty;

  /// The position to show for [id] right now, or [target] when not animating.
  LatLng current(String id, LatLng target) => _tweens[id]?.value ?? target;

  /// Starts (or retargets) a move of [id] from where it currently is.
  void moveTo(String id, LatLng from, LatLng to, MarkerAnimation animation) {
    final start = current(id, from);
    if (animation.duration == Duration.zero || start == to) {
      _tweens.remove(id);
      return;
    }
    _tweens[id] = _Tween(start, to, animation.duration, animation.curve);
  }

  /// Moves time forward by [dt]. Finished tweens are removed.
  void advance(Duration dt) {
    for (final t in _tweens.values) {
      t.elapsed += dt;
    }
    _tweens.removeWhere((_, t) => t.t >= 1);
  }

  /// Forgets [id].
  void remove(String id) => _tweens.remove(id);

  /// Forgets all moves.
  void clear() => _tweens.clear();
}
