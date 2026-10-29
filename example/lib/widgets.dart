import 'package:flutter/material.dart';

import 'data.dart';

/// A rounded price tag with a pointer, used as a marker icon.
class PricePin extends StatelessWidget {
  const PricePin({
    super.key,
    required this.price,
    this.selected = false,
    this.color = const Color(0xFF0F766E),
  });

  final int price;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF111827) : color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: selected ? 14 : 10, vertical: selected ? 8 : 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(selected ? 18 : 14),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: Text(
            '\$$price',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: selected ? 16 : 14,
              height: 1.1,
            ),
          ),
        ),
        CustomPaint(size: const Size(12, 7), painter: _Pointer(bg)),
      ],
    );
  }
}

class _Pointer extends CustomPainter {
  _Pointer(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, -1)
        ..lineTo(size.width, -1)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_Pointer old) => old.color != color;
}

/// A round "avatar" drawn with gradients and initials (no photos).
class AvatarPin extends StatelessWidget {
  const AvatarPin({super.key, required this.initials, required this.hue});

  final String initials;
  final double hue;

  @override
  Widget build(BuildContext context) {
    final a = HSLColor.fromAHSL(1, hue, .7, .55).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 40) % 360, .75, .42).toColor();
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [a, b],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }
}

/// Content of the info window: a real interactive widget.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, this.onOpen});

  final Place place;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final hue = (place.name.hashCode % 360).toDouble().abs();
    return SizedBox(
      width: 220,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: [
                HSLColor.fromAHSL(1, hue, .6, .62).toColor(),
                HSLColor.fromAHSL(1, (hue + 50) % 360, .6, .45).toColor(),
              ]),
            ),
            child: const Icon(Icons.storefront, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFF59E0B)),
                  Text(
                      ' ${place.rating.toStringAsFixed(1)}  ·  \$${place.price}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF4B5563))),
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: FilledButton(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontSize: 12.5)),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
