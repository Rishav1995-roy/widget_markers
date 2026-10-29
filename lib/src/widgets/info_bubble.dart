import 'package:flutter/material.dart';

/// Look of an [InfoBubble].
@immutable
class InfoBubbleStyle {
  /// Creates a bubble style.
  const InfoBubbleStyle({
    this.color = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.elevation = 6,
    this.shadowColor = const Color(0x66000000),
    this.padding = const EdgeInsets.all(12),
    this.tailSize = const Size(16, 9),
    this.borderColor,
    this.borderWidth = 0,
  });

  /// Background colour.
  final Color color;

  /// Corner radius.
  final BorderRadius borderRadius;

  /// Shadow strength (blur is twice this value). Zero removes the shadow.
  final double elevation;

  /// Shadow colour.
  final Color shadowColor;

  /// Space around the content.
  final EdgeInsets padding;

  /// Width and height of the tail pointing at the marker. Height 0 hides it.
  final Size tailSize;

  /// Optional outline colour.
  final Color? borderColor;

  /// Outline width (used with [borderColor]).
  final double borderWidth;
}

/// A rounded card with a tail, the usual shape of an info window.
class InfoBubble extends StatelessWidget {
  /// Creates a bubble around [child].
  const InfoBubble({
    super.key,
    required this.child,
    this.style = const InfoBubbleStyle(),
  });

  /// Content.
  final Widget child;

  /// Look of the bubble.
  final InfoBubbleStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A plain DecoratedBox (not Material elevation) so the shadow looks the
        // same on every platform and renders identically off-screen.
        DecoratedBox(
          decoration: BoxDecoration(
            color: style.color,
            borderRadius: style.borderRadius,
            border: style.borderColor == null
                ? null
                : Border.all(
                    color: style.borderColor!, width: style.borderWidth),
            boxShadow: style.elevation <= 0
                ? null
                : [
                    BoxShadow(
                      color: style.shadowColor,
                      blurRadius: style.elevation * 2,
                      offset: Offset(0, style.elevation / 2),
                    ),
                  ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: style.padding, child: child),
          ),
        ),
        if (style.tailSize.height > 0)
          CustomPaint(
            size: style.tailSize,
            painter: _TailPainter(style.color),
          ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, -1)
      ..lineTo(size.width, -1)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
