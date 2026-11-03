import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';

enum _MapMode { live, heatmap }

enum _BaseMap { street, satellite }

enum HeatmapWindow { week, month, all }

class HeatmapPoint {
  const HeatmapPoint({required this.point, required this.weight});

  final LatLng point;
  final int weight;
}

class MapPage extends StatefulWidget {
  const MapPage({
    required this.active,
    required this.trackingEnabled,
    required this.userId,
    required this.locationService,
    required this.firestoreService,
    required this.tripService,
    super.key,
  });

  final bool active;
  final bool trackingEnabled;
  final String userId;
  final LocationService locationService;
  final FirestoreService firestoreService;
  final TripService tripService;

  static List<LatLng> appendTrackingPoint(
    List<LatLng> points,
    LatLng next, {
    double minimumDistanceMeters = 5,
  }) {
    if (points.isNotEmpty &&
        const Distance().as(LengthUnit.Meter, points.last, next) <
            minimumDistanceMeters) {
      return points;
    }
    final updated = [...points, next];
    return updated.length <= 3000
        ? updated
        : updated.sublist(updated.length - 3000);
  }

  static List<List<LatLng>> buildTrackingSegments(
    Iterable<Position> positions,
  ) {
    final segments = <List<LatLng>>[];
    Position? previous;
    for (final position in positions) {
      final point = LatLng(position.latitude, position.longitude);
      if (previous == null ||
          !TripService.samplesAreContinuous(previous, position)) {
        segments.add([point]);
      } else {
        segments[segments.length - 1] = appendTrackingPoint(
          segments.last,
          point,
          minimumDistanceMeters:
              (position.accuracy / 2).clamp(3, 12).toDouble(),
        );
      }
      previous = position;
    }
    return segments;
  }

  static List<HeatmapPoint> heatmapPoints(
    Iterable<TripEntry> trips, {
    required DateTime now,
    required HeatmapWindow window,
  }) {
    final cutoff = switch (window) {
      HeatmapWindow.week => now.subtract(const Duration(days: 7)),
      HeatmapWindow.month => now.subtract(const Duration(days: 30)),
      HeatmapWindow.all => DateTime.fromMillisecondsSinceEpoch(0),
    };
    final bucketPoints = <String, LatLng>{};
    final bucketWeights = <String, int>{};
    for (final trip in trips) {
      if (trip.startedAt.isBefore(cutoff)) continue;
      for (final point in trip.points) {
        final latitude = (point.latitude * 1000).round() / 1000;
        final longitude = (point.longitude * 1000).round() / 1000;
        final key =
            '${latitude.toStringAsFixed(3)}:${longitude.toStringAsFixed(3)}';
        bucketPoints.putIfAbsent(key, () => LatLng(latitude, longitude));
        bucketWeights.update(key, (weight) => weight + 1, ifAbsent: () => 1);
      }
    }
    return [
      for (final key in bucketPoints.keys)
        HeatmapPoint(point: bucketPoints[key]!, weight: bucketWeights[key]!),
    ];
  }

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final Stream<List<FamilyContact>> _familyContacts;
  StreamSubscription<Position>? _positionSubscription;
  final MapController _mapController = MapController();
  _MapMode _mode = _MapMode.live;
  _BaseMap _baseMap = _BaseMap.street;
  HeatmapWindow _heatWindow = HeatmapWindow.week;
  LatLng? _currentLocation;
  List<List<LatLng>> _trackingTraceSegments = [];
  Position? _lastTracePosition;
  bool _locating = false;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _opened = widget.active;
    if (widget.trackingEnabled) {
      final positions = widget.locationService.trackedPositions;
      _trackingTraceSegments = MapPage.buildTrackingSegments(positions);
      if (positions.isNotEmpty) _lastTracePosition = positions.last;
    }
    _familyContacts =
        widget.firestoreService.watchFamilyContacts(widget.userId);
    if (_opened) unawaited(_refreshCurrentLocation());
    _positionSubscription =
        widget.locationService.positionStream.listen((position) {
      if (!mounted) return;
      final point = _positionToLatLng(position);
      if (point == null) return;
      setState(() {
        _currentLocation = point;
        if (widget.trackingEnabled) {
          final previous = _lastTracePosition;
          if (previous == null ||
              !TripService.samplesAreContinuous(previous, position)) {
            _trackingTraceSegments = [
              ..._trackingTraceSegments,
              [point]
            ];
          } else {
            _trackingTraceSegments = [
              ..._trackingTraceSegments.take(_trackingTraceSegments.length - 1),
              MapPage.appendTrackingPoint(
                _trackingTraceSegments.last,
                point,
                minimumDistanceMeters:
                    (position.accuracy / 2).clamp(3, 12).toDouble(),
              ),
            ];
          }
          _lastTracePosition = position;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trackingEnabled && !oldWidget.trackingEnabled) {
      final positions = widget.locationService.trackedPositions;
      _trackingTraceSegments = MapPage.buildTrackingSegments(positions);
      _lastTracePosition = positions.isEmpty ? null : positions.last;
    } else if (!widget.trackingEnabled && oldWidget.trackingEnabled) {
      _lastTracePosition = null;
    }
    if (widget.active && !oldWidget.active) {
      _opened = true;
      _currentLocation = null;
      unawaited(_refreshCurrentLocation());
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  LatLng? _positionToLatLng(Position? position) {
    if (position == null ||
        !position.accuracy.isFinite ||
        position.accuracy > LocationService.maximumAcceptedAccuracyMeters) {
      return null;
    }
    return LatLng(position.latitude, position.longitude);
  }

  LatLng get _initialTarget {
    if (_currentLocation case final current?) return current;
    final lastKnown =
        _positionToLatLng(widget.locationService.lastKnownPosition);
    if (lastKnown != null) return lastKnown;
    for (final trip in widget.tripService.trips) {
      if (trip.points.isNotEmpty) {
        final point = trip.points.first;
        return LatLng(point.latitude, point.longitude);
      }
    }
    return const LatLng(0, 0);
  }

  List<Marker> _markers(List<FamilyContact> contacts) {
    final markers = <Marker>[];
    final current = _currentLocation;
    if (current != null) {
      markers.add(
        Marker(
          point: current,
          width: 52,
          height: 58,
          child: const _MapPin(label: 'You', color: BeaconColors.lime),
        ),
      );
    }

    final now = DateTime.now();
    for (final contact in contacts) {
      final emergencyLocation = contact.emergencyActive &&
              contact.emergencyExpiresAt?.isAfter(now) != false
          ? (contact.emergencyLatitude, contact.emergencyLongitude)
          : (null, null);
      final latitude = emergencyLocation.$1 ?? contact.latitude;
      final longitude = emergencyLocation.$2 ?? contact.longitude;
      if (latitude == null || longitude == null) continue;
      final updatedAt = contact.emergencyActive
          ? contact.emergencyUpdatedAt
          : contact.locationUpdatedAt;
      if (!contact.emergencyActive &&
          (updatedAt == null ||
              now.difference(updatedAt) > const Duration(minutes: 30))) {
        continue;
      }
      markers.add(
        Marker(
          point: LatLng(latitude, longitude),
          width: 76,
          height: 66,
          child: _MapPin(
            label: contact.emergencyActive ? 'SOS' : contact.name,
            color: contact.emergencyActive
                ? BeaconColors.coral
                : BeaconColors.blue,
            alert: contact.emergencyActive,
            subtitle: contact.emergencyActive
                ? 'Alert active'
                : _relativeTime(updatedAt),
          ),
        ),
      );
    }
    return markers;
  }

  List<CircleMarker> _heatCircles() {
    final points = MapPage.heatmapPoints(
      widget.tripService.trips,
      now: DateTime.now(),
      window: _heatWindow,
    );
    return [
      for (final point in points) ...[
        CircleMarker(
          point: point.point,
          radius: 48,
          color: Color.fromARGB(
            math.min(24 + point.weight * 4, 64),
            228,
            90,
            69,
          ),
        ),
        CircleMarker(
          point: point.point,
          radius: 27,
          color: Color.fromARGB(
            math.min(40 + point.weight * 8, 112),
            242,
            181,
            76,
          ),
        ),
        CircleMarker(
          point: point.point,
          radius: 12,
          color: Color.fromARGB(
            math.min(64 + point.weight * 12, 164),
            225,
            84,
            66,
          ),
        ),
      ],
    ];
  }

  Future<void> _centerOnMe() async {
    setState(() => _locating = true);
    try {
      final found = await _refreshCurrentLocation();
      if (!found) {
        _showMessage('Allow location access to center the map on you.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<bool> _refreshCurrentLocation() async {
    final position = await widget.locationService.getCurrentPosition();
    if (!mounted || position == null) return false;
    final target = _positionToLatLng(position);
    if (target == null) return false;
    setState(() => _currentLocation = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapController.move(target, 15);
    });
    return true;
  }

  Future<void> _fitVisibleLocations(List<FamilyContact> contacts) async {
    final locations = <LatLng>[
      if (_currentLocation != null) _currentLocation!,
      for (final contact in contacts)
        if (contact.latitude != null && contact.longitude != null)
          LatLng(contact.latitude!, contact.longitude!),
    ];
    if (locations.isEmpty) {
      _showMessage('No recent locations are available to show.');
      return;
    }
    if (locations.length == 1) {
      _mapController.move(locations.single, 14);
      return;
    }
    final center = LatLng(
      locations.fold<double>(0, (sum, point) => sum + point.latitude) /
          locations.length,
      locations.fold<double>(0, (sum, point) => sum + point.longitude) /
          locations.length,
    );
    _mapController.move(center, 12);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      return const ColoredBox(color: BeaconColors.paper);
    }
    final trips = widget.tripService.trips;
    final points = MapPage.heatmapPoints(
      trips,
      now: DateTime.now(),
      window: _heatWindow,
    );
    return StreamBuilder<List<FamilyContact>>(
      stream: _familyContacts,
      builder: (context, snapshot) {
        final contacts = snapshot.data ?? const <FamilyContact>[];
        final markers =
            _mode == _MapMode.live ? _markers(contacts) : <Marker>[];
        return Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialTarget,
                initialZoom: _currentLocation == null ? 2 : 14,
                maxZoom: 23,
              ),
              children: [
                TileLayer(
                  urlTemplate: _baseMap == _BaseMap.street
                      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                      : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.example.beacon',
                  maxZoom: 23,
                  maxNativeZoom: _baseMap == _BaseMap.street ? 19 : 17,
                ),
                if (_mode == _MapMode.live) MarkerLayer(markers: markers),
                if (_mode == _MapMode.live &&
                    widget.trackingEnabled &&
                    _trackingTraceSegments.any((segment) => segment.length > 1))
                  PolylineLayer(
                    polylines: [
                      for (final segment in _trackingTraceSegments)
                        if (segment.length > 1)
                          Polyline(
                            points: segment,
                            strokeWidth: 5,
                            color: BeaconColors.lime,
                            borderColor: BeaconColors.ink,
                            borderStrokeWidth: 1.5,
                          ),
                    ],
                  ),
                if (_mode == _MapMode.heatmap)
                  CircleLayer(circles: _heatCircles()),
                RichAttributionWidget(
                  attributions: [
                    if (_baseMap == _BaseMap.street)
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(Uri.parse(
                          'https://www.openstreetmap.org/copyright',
                        )),
                      )
                    else
                      const TextSourceAttribution(
                        'Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community',
                        onTap: null,
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _MapHeader(
                    mode: _mode,
                    onModeChanged: (mode) => setState(() => _mode = mode),
                    baseMap: _baseMap,
                    onBaseMapChanged: (baseMap) =>
                        setState(() => _baseMap = baseMap),
                    heatWindow: _heatWindow,
                    onHeatWindowChanged: (window) =>
                        setState(() => _heatWindow = window),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
                child: _MapStatus(
                  mode: _mode,
                  memberCount: contacts
                      .where((contact) => contact.latitude != null)
                      .length,
                  pointCount: points.length,
                  trackingEnabled: widget.locationService.trackingEnabled,
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 120,
              child: Column(
                children: [
                  _MapAction(
                    tooltip: 'Show your circle',
                    icon: Icons.group_outlined,
                    onPressed: () => _fitVisibleLocations(contacts),
                  ),
                  const SizedBox(height: 8),
                  _MapAction(
                    tooltip: 'Center on me',
                    icon: _locating ? Icons.more_horiz : Icons.my_location,
                    onPressed: _locating ? null : _centerOnMe,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.mode,
    required this.onModeChanged,
    required this.baseMap,
    required this.onBaseMapChanged,
    required this.heatWindow,
    required this.onHeatWindowChanged,
  });

  final _MapMode mode;
  final ValueChanged<_MapMode> onModeChanged;
  final _BaseMap baseMap;
  final ValueChanged<_BaseMap> onBaseMapChanged;
  final HeatmapWindow heatWindow;
  final ValueChanged<HeatmapWindow> onHeatWindowChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'YOUR PEOPLE, YOUR PLACES',
            style: TextStyle(
              color: BeaconColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Map',
            style: TextStyle(
              color: BeaconColors.ink,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          SegmentedButton<_MapMode>(
            segments: const [
              ButtonSegment(
                value: _MapMode.live,
                icon: Icon(Icons.people_alt_outlined),
                label: Text('Live'),
              ),
              ButtonSegment(
                value: _MapMode.heatmap,
                icon: Icon(Icons.whatshot_outlined),
                label: Text('Heatmap'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<_BaseMap>(
            segments: const [
              ButtonSegment(
                value: _BaseMap.street,
                icon: Icon(Icons.map_outlined),
                label: Text('Street'),
              ),
              ButtonSegment(
                value: _BaseMap.satellite,
                icon: Icon(Icons.satellite_alt_outlined),
                label: Text('Satellite'),
              ),
            ],
            selected: {baseMap},
            onSelectionChanged: (selection) =>
                onBaseMapChanged(selection.first),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
            ),
          ),
          if (mode == _MapMode.heatmap) ...[
            const SizedBox(height: 8),
            SegmentedButton<HeatmapWindow>(
              segments: const [
                ButtonSegment(value: HeatmapWindow.week, label: Text('Week')),
                ButtonSegment(value: HeatmapWindow.month, label: Text('Month')),
                ButtonSegment(value: HeatmapWindow.all, label: Text('All')),
              ],
              selected: {heatWindow},
              onSelectionChanged: (selection) =>
                  onHeatWindowChanged(selection.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapStatus extends StatelessWidget {
  const _MapStatus({
    required this.mode,
    required this.memberCount,
    required this.pointCount,
    required this.trackingEnabled,
  });

  final _MapMode mode;
  final int memberCount;
  final int pointCount;
  final bool trackingEnabled;

  @override
  Widget build(BuildContext context) {
    final title = mode == _MapMode.live
        ? trackingEnabled
            ? 'LIVE · $memberCount FAMILY'
            : '$memberCount FAMILY LOCATIONS'
        : '$pointCount MOVEMENT POINTS';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BeaconColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == _MapMode.live ? Icons.circle : Icons.whatshot,
              size: 12,
              color: BeaconColors.lime,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: BeaconColors.ink),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
    required this.color,
    this.subtitle,
    this.alert = false,
  });

  final String label;
  final String? subtitle;
  final Color color;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 5,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Icon(
            alert ? Icons.sos_rounded : Icons.person_pin_circle,
            color: BeaconColors.ink,
            size: 18,
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  style: const TextStyle(
                    color: BeaconColors.muted,
                    fontSize: 8,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime? value) {
  if (value == null) return 'recently';
  final age = DateTime.now().difference(value);
  if (age.inMinutes < 1) return 'just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}
