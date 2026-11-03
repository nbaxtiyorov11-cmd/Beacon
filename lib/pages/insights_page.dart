import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';
import '../widgets/beacon_widgets.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({required this.tripService, super.key});

  final TripService tripService;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  String _period = 'Week';

  DateTime _periodStart(DateTime now) {
    return switch (_period) {
      'Month' => DateTime(now.year, now.month),
      'Year' => DateTime(now.year),
      _ => _dateOnly(now).subtract(const Duration(days: 6)),
    };
  }

  DateTime _previousPeriodStart(DateTime now) {
    return switch (_period) {
      'Month' => DateTime(now.year, now.month - 1),
      'Year' => DateTime(now.year - 1),
      _ => _periodStart(now).subtract(const Duration(days: 7)),
    };
  }

  DateTime _periodEnd(DateTime now) {
    return switch (_period) {
      'Month' => DateTime(now.year, now.month + 1),
      'Year' => DateTime(now.year + 1),
      _ => _dateOnly(now).add(const Duration(days: 1)),
    };
  }

  List<TripEntry> _tripsBetween(DateTime start, DateTime end) =>
      widget.tripService.trips
          .where((trip) =>
              !trip.startedAt.isBefore(start) && trip.startedAt.isBefore(end))
          .toList();

  double _distanceOf(List<TripEntry> trips) => trips.fold<double>(
        0,
        (sum, trip) => sum + trip.distanceMeters,
      );

  List<double> _chartValues(DateTime now) {
    final start = _periodStart(now);
    final end = _periodEnd(now);
    final bucketCount = switch (_period) {
      'Month' => 5,
      'Year' => 12,
      _ => 7,
    };
    final periodDays = end.difference(start).inDays;
    return List.generate(bucketCount, (index) {
      final bucketStart = _period == 'Year'
          ? DateTime(start.year, index + 1)
          : start
              .add(Duration(days: (periodDays * index / bucketCount).floor()));
      final bucketEnd = _period == 'Year'
          ? DateTime(start.year, index + 2)
          : start.add(
              Duration(days: (periodDays * (index + 1) / bucketCount).floor()));
      return _distanceOf(_tripsBetween(bucketStart, bucketEnd));
    });
  }

  List<String> _chartLabels(DateTime now) {
    return switch (_period) {
      'Month' => const ['1', '2', '3', '4', '5'],
      'Year' => const [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D'
        ],
      _ => List.generate(7, (index) {
          final day = _dateOnly(now).subtract(Duration(days: 6 - index));
          return _weekdayShortName(day.weekday);
        }),
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentStart = _periodStart(now);
    final currentEnd = _periodEnd(now);
    final currentTrips = _tripsBetween(currentStart, currentEnd);
    final previousTrips = _tripsBetween(
      _previousPeriodStart(now),
      currentStart,
    );
    final distanceMeters = _distanceOf(currentTrips);
    final totalDistance = distanceMeters / 1000;
    final previousDistance = _distanceOf(previousTrips);
    final changePercent = previousDistance == 0
        ? null
        : ((distanceMeters - previousDistance) / previousDistance * 100)
            .round();
    final chartValues = _chartValues(now);
    final chartLabels = _chartLabels(now);
    final tripMinutes = currentTrips.fold<int>(
      0,
      (sum, trip) => sum + trip.totalMinutes.round(),
    );
    final averageSpeed =
        tripMinutes == 0 ? 0.0 : distanceMeters / 1000 / (tripMinutes / 60);
    final busiestDay = _busiestDay(currentTrips);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const PageHeading(
          eyebrow: 'Patterns, not pressure',
          title: 'Your insights',
          subtitle: 'A clearer picture of how you move.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Week', label: Text('Week')),
              ButtonSegment(value: 'Month', label: Text('Month')),
              ButtonSegment(value: 'Year', label: Text('Year')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) =>
                setState(() => _period = selection.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: BeaconColors.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_period.toUpperCase()}LY DISTANCE',
                  style: const TextStyle(
                    color: Color(0xFFB8C7BD),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalDistance == 0
                          ? '0.0'
                          : totalDistance.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'km',
                        style:
                            TextStyle(color: BeaconColors.lime, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                _DistanceChart(values: chartValues, labels: chartLabels),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Icon(
                      changePercent == null
                          ? Icons.info_outline
                          : changePercent >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                      size: 16,
                      color: BeaconColors.lime,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        changePercent == null
                            ? 'No previous period data to compare yet'
                            : '${changePercent >= 0 ? '+' : ''}$changePercent% vs. previous ${_period.toLowerCase()}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 21),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SectionHeading('The short version'),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _InsightRow(
                icon: Icons.home_outlined,
                color: BeaconColors.blue,
                title: totalDistance == 0
                    ? 'No movement recorded'
                    : 'Movement total',
                detail: totalDistance == 0
                    ? 'Start a tracked trip to build your first summary.'
                    : 'You covered ${totalDistance.toStringAsFixed(1)} km across ${currentTrips.length} trip${currentTrips.length == 1 ? '' : 's'} this ${_period.toLowerCase()}.',
              ),
              const SizedBox(height: 9),
              _InsightRow(
                icon: Icons.explore_outlined,
                color: BeaconColors.coral,
                title: busiestDay == null
                    ? 'No active day yet'
                    : 'Most active day',
                detail: busiestDay == null
                    ? 'A day-by-day pattern will appear after trips are recorded.'
                    : '${_weekdayName(busiestDay.key.weekday)} · ${(busiestDay.value / 1000).toStringAsFixed(1)} km.',
              ),
              const SizedBox(height: 9),
              _InsightRow(
                icon: Icons.directions_walk,
                color: BeaconColors.forest,
                title: 'Average speed',
                detail: tripMinutes == 0
                    ? 'No timed trip data in this period yet.'
                    : '${averageSpeed.toStringAsFixed(1)} km/h across timed trips.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SurfacePanel(
      padding: 15,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: BeaconColors.muted,
                    fontSize: 12,
                    height: 1.35,
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

class _DistanceChart extends StatelessWidget {
  const _DistanceChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<double>(
      0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );
    return SizedBox(
      height: 104,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: maximum == 0
                            ? 3
                            : 10 + values[index] / maximum * 54,
                        width: 14,
                        decoration: BoxDecoration(
                          color: values[index] == maximum && maximum > 0
                              ? BeaconColors.lime
                              : const Color(0xFF789086),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[index],
                      style: const TextStyle(
                          color: Color(0xFFB8C7BD), fontSize: 9)),
                ],
              ),
            ),
            if (index < values.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

MapEntry<DateTime, double>? _busiestDay(List<TripEntry> trips) {
  if (trips.isEmpty) return null;
  final totals = <DateTime, double>{};
  for (final trip in trips) {
    final day = _dateOnly(trip.startedAt);
    totals.update(
      day,
      (distance) => distance + trip.distanceMeters,
      ifAbsent: () => trip.distanceMeters,
    );
  }
  return totals.entries.reduce(
    (first, second) => first.value >= second.value ? first : second,
  );
}

String _weekdayName(int weekday) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][weekday - 1];

String _weekdayShortName(int weekday) => const [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ][weekday - 1];
