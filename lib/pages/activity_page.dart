import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';
import '../widgets/beacon_widgets.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({required this.tripService, super.key});

  final TripService tripService;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int _selectedDay = 0;
  int _selectedTripIndex = 0;

  List<TripEntry> get _trips => widget.tripService.trips;

  List<TripEntry> get _visibleTrips => _trips.where((trip) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tripDay = DateTime(
          trip.startedAt.year,
          trip.startedAt.month,
          trip.startedAt.day,
        );
        return today.difference(tripDay).inDays == _selectedDay;
      }).toList();

  TripEntry? get _activeTrip {
    final trips = _visibleTrips;
    if (trips.isEmpty) return null;
    if (_selectedTripIndex >= trips.length) {
      _selectedTripIndex = trips.length - 1;
    }
    return trips[_selectedTripIndex];
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime value) {
    return '${value.day}/${value.month}/${value.year}';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final trip = _activeTrip;
    final trips = _visibleTrips;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeading(
          eyebrow: 'Your places and trips',
          title: 'Movement history',
          subtitle: 'A simple view of where your day took you.',
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _selectedDay == index;
              return ChoiceChip(
                label: Text(index == 0 ? 'Today' : '${index}d ago'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedDay = index),
                selectedColor: BeaconColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : BeaconColors.ink,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected ? BeaconColors.ink : BeaconColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 185,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EBDE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HistoryMapPainter(
                      trip: trip,
                    ),
                  ),
                ),
                Positioned(
                  left: 15,
                  top: 13,
                  child: _MapTag(
                    icon: Icons.layers_outlined,
                    text: trip == null ? 'NO ROUTE' : 'DAY ROUTE',
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 14,
                  child: Text(
                    trip == null
                        ? '0.0 km  ·  0 stops'
                        : '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km  ·  ${trip.points.length} stops',
                    style: const TextStyle(
                      color: BeaconColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 12,
                  child: IconButton.filledTonal(
                    tooltip: 'Map view',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Interactive maps will be added next.'),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeading(
            'Trip detail',
            action:
                trip == null ? '0 trips' : '${trip.distanceMeters.round()} m',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SurfacePanel(
            child: trip == null
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No movement trip has been recorded yet. Start tracking from the Today screen.',
                      style: TextStyle(color: BeaconColors.muted),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDate(trip.startedAt),
                                  style: const TextStyle(
                                    color: BeaconColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    color: BeaconColors.ink,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: BeaconColors.lime.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDuration(trip.startedAt, trip.endedAt),
                              style: const TextStyle(
                                color: BeaconColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PlaceListTile(
                        name: 'Trip started',
                        detail:
                            '${_formatTime(trip.startedAt)} · ${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
                        time: _formatTime(trip.startedAt),
                        icon: Icons.my_location,
                        color: BeaconColors.blue,
                      ),
                      const Divider(height: 1, color: BeaconColors.line),
                      PlaceListTile(
                        name: 'Movement active',
                        detail:
                            '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h average',
                        time: _formatTime(trip.endedAt),
                        icon: Icons.directions_run,
                        color: BeaconColors.coral,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeading(
            'Recent trips',
            action: trips.isEmpty ? '0' : '${trips.length}',
          ),
        ),
        if (trips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SurfacePanel(
              child: Column(
                children: List.generate(trips.length, (index) {
                  final item = trips[index];
                  final selected = index == _selectedTripIndex;
                  return InkWell(
                    onTap: () => setState(() => _selectedTripIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? BeaconColors.ink.withValues(alpha: 0.04)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: BeaconColors.coral.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.route_outlined,
                              color: BeaconColors.coral,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name?.trim().isNotEmpty == true
                                      ? item.name!.trim()
                                      : '${item.startedAt.day}/${item.startedAt.month} · ${_formatTime(item.startedAt)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${(item.distanceMeters / 1000).toStringAsFixed(1)} km · ${item.averageSpeedKmh.toStringAsFixed(1)} km/h',
                                  style: const TextStyle(
                                    color: BeaconColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            selected ? Icons.check_circle : Icons.chevron_right,
                            color: selected
                                ? BeaconColors.ink
                                : BeaconColors.muted,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            trip == null
                ? 'WAITING FOR FIRST TRACKED JOURNEY'
                : 'LIVE TRACKING HISTORY • ${trip.distanceMeters.round()} m recorded',
            style: const TextStyle(
              color: BeaconColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapTag extends StatelessWidget {
  const _MapTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: BeaconColors.ink),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: BeaconColors.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMapPainter extends CustomPainter {
  const _HistoryMapPainter({required this.trip});

  final TripEntry? trip;

  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = const Color(0xFFD2DDCC);
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    final routePaint = Paint()
      ..color = BeaconColors.coral
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 5; column++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              column * size.width / 5 + 7,
              row * size.height / 3 + 7,
              size.width / 5 - 14,
              size.height / 3 - 14,
            ),
            const Radius.circular(4),
          ),
          blockPaint,
        );
      }
    }

    final road = Path()
      ..moveTo(size.width * 0.1, size.height * 0.67)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.12,
        size.width * 0.66,
        size.height * 0.92,
        size.width * 0.91,
        size.height * 0.27,
      );
    canvas.drawPath(road, roadPaint);

    if (trip == null || trip!.points.length < 2) {
      return;
    }

    final points = trip!.points;
    final minLat =
        points.map((point) => point.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat =
        points.map((point) => point.latitude).reduce((a, b) => a > b ? a : b);
    final minLng =
        points.map((point) => point.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng =
        points.map((point) => point.longitude).reduce((a, b) => a > b ? a : b);

    final latRange = maxLat - minLat == 0 ? 1.0 : maxLat - minLat;
    final lngRange = maxLng - minLng == 0 ? 1.0 : maxLng - minLng;
    final path = Path();

    for (var index = 0; index < points.length; index++) {
      final x = ((points[index].longitude - minLng) / lngRange) * size.width;
      final y = size.height -
          (((points[index].latitude - minLat) / latRange) * size.height);
      final offset = Offset(x, y);
      if (index == 0 || points[index].segmentStart) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(path, routePaint);

    final first = points.first;
    final last = points.last;
    final firstX = ((first.longitude - minLng) / lngRange) * size.width;
    final firstY =
        size.height - (((first.latitude - minLat) / latRange) * size.height);
    final lastX = ((last.longitude - minLng) / lngRange) * size.width;
    final lastY =
        size.height - (((last.latitude - minLat) / latRange) * size.height);

    final pointPaint = Paint()..color = Colors.white;
    final innerPaint = Paint()..color = BeaconColors.ink;
    canvas.drawCircle(Offset(firstX, firstY), 7, pointPaint);
    canvas.drawCircle(Offset(firstX, firstY), 4, innerPaint);
    canvas.drawCircle(Offset(lastX, lastY), 7, pointPaint);
    canvas.drawCircle(Offset(lastX, lastY), 4, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _HistoryMapPainter oldDelegate) =>
      oldDelegate.trip != trip;
}
