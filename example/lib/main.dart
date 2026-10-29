import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:widget_markers/widget_markers.dart';

import 'data.dart';
import 'places_map.dart';
import 'stand_in_map.dart';
import 'widgets.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'widget_markers',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0F766E), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF0F766E),
          brightness: Brightness.dark,
          useMaterial3: true),
      home: Home(
        onToggleTheme: () => setState(() {
          _mode = Theme.of(context).brightness == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MarkersTab(),
      const ClustersTab(),
      const AnimatedTab(),
      const CustomizeTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('widget_markers'),
        actions: [
          IconButton(
              onPressed: widget.onToggleTheme,
              icon: const Icon(Icons.brightness_6_outlined))
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.place_outlined), label: 'Markers'),
          NavigationDestination(
              icon: Icon(Icons.bubble_chart_outlined), label: 'Clusters'),
          NavigationDestination(icon: Icon(Icons.moving), label: 'Animated'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Customize'),
        ],
      ),
    );
  }
}

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Widget markers + a widget info window that follows the camera.
class MarkersTab extends StatefulWidget {
  const MarkersTab({super.key});

  @override
  State<MarkersTab> createState() => _MarkersTabState();
}

class _MarkersTabState extends State<MarkersTab> {
  final _places = samplePlaces(count: 14);
  final _standIn = StandInMapController();
  final _controller = WidgetMarkersController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlacesMap(
      places: _places,
      markersController: _controller,
      standIn: _standIn,
      dark: _dark(context),
      settings: const MapSettings(clustering: false),
      initialCamera:
          const CameraPosition(target: LatLng(12.9716, 77.5946), zoom: 12.4),
      onOpen: (p) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Opened ${p.name}'))),
    );
  }
}

/// Widget-built cluster badges.
class ClustersTab extends StatefulWidget {
  const ClustersTab({super.key});

  @override
  State<ClustersTab> createState() => _ClustersTabState();
}

class _ClustersTabState extends State<ClustersTab> {
  final _places = samplePlaces();
  final _standIn = StandInMapController();
  final _controller = WidgetMarkersController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlacesMap(
      places: _places,
      markersController: _controller,
      standIn: _standIn,
      dark: _dark(context),
    );
  }
}

/// Markers that glide to new positions.
class AnimatedTab extends StatefulWidget {
  const AnimatedTab({super.key});

  @override
  State<AnimatedTab> createState() => _AnimatedTabState();
}

class _AnimatedTabState extends State<AnimatedTab> {
  int _step = 0;
  final _standIn = StandInMapController();
  final _controller = WidgetMarkersController();

  static const _route = [
    LatLng(12.9716, 77.5946),
    LatLng(12.9780, 77.6100),
    LatLng(12.9650, 77.6200),
    LatLng(12.9560, 77.6000),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = [
      for (var i = 0; i < 3; i++)
        WidgetMarker(
          id: 'courier$i',
          position: LatLng(
            _route[(_step + i) % _route.length].latitude + i * 0.002,
            _route[(_step + i) % _route.length].longitude,
          ),
          anchor: const Offset(0.5, 0.5),
          child:
              AvatarPin(initials: ['AK', 'MR', 'JT'][i], hue: 30.0 + i * 110),
        ),
    ];
    return Stack(children: [
      WidgetMarkerMap(
        controller: _controller,
        initialCameraPosition:
            const CameraPosition(target: LatLng(12.9680, 77.6050), zoom: 13.5),
        markers: markers,
        animation:
            const MarkerAnimation(duration: Duration(milliseconds: 1400)),
        mapBuilder: (context, b) => StandInMap(
          bindings: b,
          controller: _standIn,
          dark: _dark(context),
          initialCamera: const CameraPosition(
              target: LatLng(12.9680, 77.6050), zoom: 13.5),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: () => setState(() => _step++),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Move couriers'),
        ),
      ),
    ]);
  }
}

/// Theming: every look in the package is a plain value you can change.
class CustomizeTab extends StatefulWidget {
  const CustomizeTab({super.key});

  @override
  State<CustomizeTab> createState() => _CustomizeTabState();
}

class _CustomizeTabState extends State<CustomizeTab> {
  MapSettings _s = const MapSettings();
  final _places = samplePlaces(count: 40);
  final _standIn = StandInMapController();
  final _controller = WidgetMarkersController();

  static const _colors = [
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _slider(
      String label, double v, double min, double max, ValueChanged<double> on) {
    return Row(children: [
      SizedBox(
          width: 110, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(child: Slider(value: v, min: min, max: max, onChanged: on)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: PlacesMap(
          places: _places,
          settings: _s,
          markersController: _controller,
          standIn: _standIn,
          dark: _dark(context),
        ),
      ),
      Material(
        elevation: 8,
        child: SizedBox(
          height: 250,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                Row(children: [
                  const Text('Badge colour  ', style: TextStyle(fontSize: 12)),
                  for (final c in _colors)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _s = _s.copyWith(badgeColor: c)),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                width: 3,
                                color: _s.badgeColor == c
                                    ? Colors.black87
                                    : Colors.transparent)),
                      ),
                    ),
                  const Spacer(),
                  Switch(
                      value: _s.clustering,
                      onChanged: (v) =>
                          setState(() => _s = _s.copyWith(clustering: v))),
                  const Text('Cluster', style: TextStyle(fontSize: 12)),
                ]),
                _slider('Cluster cell', _s.cellSize, 30, 160,
                    (v) => setState(() => _s = _s.copyWith(cellSize: v))),
                _slider('Bubble radius', _s.bubbleRadius, 0, 28,
                    (v) => setState(() => _s = _s.copyWith(bubbleRadius: v))),
                _slider(
                    'Bubble shadow',
                    _s.bubbleElevation,
                    0,
                    16,
                    (v) =>
                        setState(() => _s = _s.copyWith(bubbleElevation: v))),
                _slider('Window gap', _s.gap, 0, 24,
                    (v) => setState(() => _s = _s.copyWith(gap: v))),
                _slider(
                    'Move animation',
                    _s.animationMs.toDouble(),
                    0,
                    2000,
                    (v) => setState(
                        () => _s = _s.copyWith(animationMs: v.round()))),
              ]),
        ),
      ),
    ]);
  }
}
