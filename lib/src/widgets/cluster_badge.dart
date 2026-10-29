import 'package:flutter/material.dart';

/// Look of a [ClusterBadge].
@immutable
class ClusterBadgeStyle {
  /// Creates a badge style.
  const ClusterBadgeStyle({
    this.color = const Color(0xFF1E88E5),
    this.textColor = Colors.white,
    this.ringColor = Colors.white,
    this.ringWidth = 3,
    this.haloColor,
    this.minSize = 36,
    this.growth = 4,
    this.maxSize = 64,
    this.textStyle,
  });

  /// Fill colour.
  final Color color;

  /// Count text colour.
  final Color textColor;

  /// Outline colour.
  final Color ringColor;

  /// Outline width.
  final double ringWidth;

  /// Soft outer halo colour; defaults to a translucent [color].
  final Color? haloColor;

  /// Diameter for a small cluster.
  final double minSize;

  /// Extra diameter per decimal digit of the count.
  final double growth;

  /// Largest diameter.
  final double maxSize;

  /// Overrides the count text style.
  final TextStyle? textStyle;

  /// A copy with some fields replaced.
  ClusterBadgeStyle copyWith({
    Color? color,
    Color? textColor,
    Color? ringColor,
    double? ringWidth,
    Color? haloColor,
    double? minSize,
    double? growth,
    double? maxSize,
    TextStyle? textStyle,
  }) =>
      ClusterBadgeStyle(
        color: color ?? this.color,
        textColor: textColor ?? this.textColor,
        ringColor: ringColor ?? this.ringColor,
        ringWidth: ringWidth ?? this.ringWidth,
        haloColor: haloColor ?? this.haloColor,
        minSize: minSize ?? this.minSize,
        growth: growth ?? this.growth,
        maxSize: maxSize ?? this.maxSize,
        textStyle: textStyle ?? this.textStyle,
      );
}

/// The default cluster icon: a round count badge that grows with the count.
class ClusterBadge extends StatelessWidget {
  /// Creates a badge for [count].
  const ClusterBadge({
    super.key,
    required this.count,
    this.style = const ClusterBadgeStyle(),
  });

  /// Number of markers in the cluster.
  final int count;

  /// Look of the badge.
  final ClusterBadgeStyle style;

  /// Diameter used for [count].
  double diameterFor(int count) {
    final digits = count.toString().length;
    return (style.minSize + (digits - 1) * style.growth * 3)
        .clamp(style.minSize, style.maxSize);
  }

  @override
  Widget build(BuildContext context) {
    final d = diameterFor(count);
    final halo = style.haloColor ?? style.color.withValues(alpha: 0.28);
    final text = count > 999 ? '999+' : '$count';
    return Container(
      width: d + 12,
      height: d + 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: halo),
      child: Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.color,
          border: Border.all(color: style.ringColor, width: style.ringWidth),
        ),
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: style.textStyle ??
              TextStyle(
                color: style.textColor,
                fontWeight: FontWeight.w700,
                fontSize: d * 0.38,
                height: 1,
              ),
        ),
      ),
    );
  }
}
