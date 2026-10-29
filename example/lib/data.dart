import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A synthetic place. All names, prices and ratings are made up.
class Place {
  const Place(
      this.id, this.name, this.kind, this.price, this.rating, this.position);

  final String id;
  final String name;
  final String kind;
  final int price;
  final double rating;
  final LatLng position;
}

const _kinds = ['Cafe', 'Bistro', 'Bakery', 'Studio', 'Loft', 'Garden'];
const _names = [
  'Mango',
  'Willow',
  'Copper',
  'Juniper',
  'Saffron',
  'Harbor',
  'Lantern',
  'Maple',
  'Indigo',
  'Pebble',
  'Cedar',
  'Ember',
  'Orchid',
  'Breeze',
];
const _hubs = [
  LatLng(12.9716, 77.5946),
  LatLng(12.9352, 77.6245),
  LatLng(13.0358, 77.5970),
  LatLng(12.9121, 77.5845),
  LatLng(12.9855, 77.7066),
];

/// Deterministic pseudo-random places around a few hubs.
List<Place> samplePlaces({int count = 72}) {
  var seed = 7;
  double next() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed / 0x7fffffff;
  }

  return [
    for (var i = 0; i < count; i++)
      () {
        final hub = _hubs[i % _hubs.length];
        final spread = i % 3 == 0 ? 0.004 : 0.02;
        return Place(
          'p$i',
          '${_names[i % _names.length]} ${_kinds[(i * 5) % _kinds.length]}',
          _kinds[(i * 5) % _kinds.length],
          18 + (next() * 90).round(),
          3.6 + next() * 1.4,
          LatLng(hub.latitude + (next() - .5) * spread * 2,
              hub.longitude + (next() - .5) * spread * 2),
        );
      }(),
  ];
}
