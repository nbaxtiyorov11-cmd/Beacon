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

  String _formatTotalDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) return '${hours}h ${remainingMinutes}m';
    return '${remainingMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final trip = _activeTrip;
    final trips = _visibleTrips;
    final totalDistance =
        trips.fold<double>(0, (total, item) => total + item.distanceMeters);
    final totalMinutes = trips.fold<int>(
      0,
      (total, item) => total + item.totalMinutes.round(),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRIPS & ROUTES',
                    style: TextStyle(
                      color: BeaconColors.forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Movement history',
                    style: TextStyle(
                      color: BeaconColors.ink,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEE9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: BeaconColors.forest,
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final selected = _selectedDay == index;
              return _HistoryDayButton(
                label: index == 0 ? 'Today' : '${index}d ago',
                selected: selected,
                onTap: () => setState(() {
                  _selectedDay = index;
                  _selectedTripIndex = 0;
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _HistoryMetric(
                label: 'DISTANCE',
                value: '${(totalDistance / 1000).toStringAsFixed(1)} km',
                icon: Icons.straighten_rounded,
                color: BeaconColors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HistoryMetric(
                label: 'TRIPS',
                value: '${trips.length}',
                icon: Icons.alt_route_rounded,
                color: BeaconColors.coral,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HistoryMetric(
                label: 'TIME',
                value: _formatTotalDuration(totalMinutes),
                icon: Icons.schedule_rounded,
                color: BeaconColors.forest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          height: 202,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: const Color(0xFFE5EBDE),
            border: Border.all(color: BeaconColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HistoryMapPainter(trip: trip),
                ),
              ),
              Positioned(
                left: 14,
                top: 13,
                child: _MapTag(
                  icon: trip == null
                      ? Icons.route_outlined
                      : Icons.navigation_rounded,
                  text: trip == null ? 'NO ROUTE' : 'ROUTE SNAPSHOT',
                ),
              ),
              Positioned(
                left: 16,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        size: 15,
                        color: BeaconColors.coral,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        trip == null
                            ? 'No route recorded'
                            : '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km · ${trip.points.length} points',
                        style: const TextStyle(
                          color: BeaconColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Trip detail',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              trip == null
                  ? 'No trip selected'
                  : '${trip.distanceMeters.round()} m',
              style: const TextStyle(
                color: BeaconColors.forest,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SurfacePanel(
          padding: 14,
          child: trip == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.route_outlined, color: BeaconColors.blue),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'No trip for this day. Choose another date or start tracking from Today.',
                          style: TextStyle(
                            color: BeaconColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7EEE9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.route_rounded,
                            color: BeaconColors.forest,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.name?.trim().isNotEmpty == true
                                    ? trip.name!.trim()
                                    : 'Recorded trip',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BeaconColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatDate(trip.startedAt)} · ${_formatTime(trip.startedAt)} to ${_formatTime(trip.endedAt)}',
                                style: const TextStyle(
                                  color: BeaconColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TripMetric(
                            label: 'DISTANCE',
                            value:
                                '${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
                            color: BeaconColors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TripMetric(
                            label: 'DURATION',
                            value:
                                _formatTotalDuration(trip.totalMinutes.round()),
                            color: BeaconColors.coral,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TripMetric(
                            label: 'AVG SPEED',
                            value:
                                '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h',
                            color: BeaconColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: BeaconColors.line),
                    const SizedBox(height: 4),
                    PlaceListTile(
                      name: 'Trip started',
                      detail:
                          '${_formatTime(trip.startedAt)} · ${(trip.distanceMeters / 1000).toStringAsFixed(1)} km',
                      time: _formatTime(trip.startedAt),
                      icon: Icons.my_location_rounded,
                      color: BeaconColors.blue,
                    ),
                    const Divider(height: 1, color: BeaconColors.line),
                    PlaceListTile(
                      name: 'Movement active',
                      detail:
                          '${trip.averageSpeedKmh.toStringAsFixed(1)} km/h average',
                      time: _formatTime(trip.endedAt),
                      icon: Icons.directions_walk_rounded,
                      color: BeaconColors.coral,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent trips',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEE9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${trips.length}',
                style: const TextStyle(
                  color: BeaconColors.forest,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (trips.isNotEmpty)
          SurfacePanel(
            padding: 12,
            child: Column(
              children: List.generate(trips.length, (index) {
                final item = trips[index];
                final selected = index == _selectedTripIndex;
                final accent = switch (index % 3) {
                  0 => BeaconColors.blue,
                  1 => BeaconColors.coral,
                  _ => BeaconColors.forest,
                };
                return Column(
                  children: [
                    if (index > 0)
                      const Divider(height: 1, color: BeaconColors.line),
                    InkWell(
                      onTap: () => setState(() => _selectedTripIndex = index),
                      borderRadius: BorderRadius.circular(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 11,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: selected ? 0.2 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                Icons.route_rounded,
                                color: accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name?.trim().isNotEmpty == true
                                        ? item.name!.trim()
                                        : '${item.startedAt.day}/${item.startedAt.month} · ${_formatTime(item.startedAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: BeaconColors.ink,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(item.distanceMeters / 1000).toStringAsFixed(1)} km · ${item.averageSpeedKmh.toStringAsFixed(1)} km/h average',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: BeaconColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: selected ? accent : BeaconColors.muted,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
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

class _TripMetric extends StatelessWidget {
  const _TripMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BeaconColors.muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDayButton extends StatelessWidget {
  const _HistoryDayButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? BeaconColors.forest : Colors.white,
            border: Border.all(
              color: selected ? BeaconColors.forest : BeaconColors.line,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 15, color: BeaconColors.lime),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : BeaconColors.ink,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BeaconColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: BeaconColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        color: BeaconColors.forest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: BeaconColors.lime),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
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
    final blockPaint = Paint()..color = const Color(0xFFD4DFD4);
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    final parkPaint = Paint()..color = const Color(0xFFB7CFB1);
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

    canvas.drawCircle(
      Offset(size.width * 0.81, size.height * 0.24),
      size.height * 0.13,
      parkPaint,
    );

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
