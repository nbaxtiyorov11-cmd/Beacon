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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MOVEMENT ANALYTICS',
                    style: TextStyle(
                      color: BeaconColors.forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your insights',
                    style: TextStyle(
                      color: BeaconColors.ink,
                      fontSize: 30,
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
                color: const Color(0xFFE6ECE4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: BeaconColors.forest,
                size: 22,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PeriodSelector(
          selectedPeriod: _period,
          onPeriodChanged: (period) => setState(() => _period = period),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 15),
          decoration: BoxDecoration(
            color: BeaconColors.ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_period.toUpperCase()}LY DISTANCE',
                      style: const TextStyle(
                        color: Color(0xFFB8C7BD),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (changePercent != null)
                    _ChangeBadge(changePercent: changePercent),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    totalDistance.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'km',
                      style: TextStyle(
                        color: BeaconColors.lime,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${currentTrips.length} ${currentTrips.length == 1 ? 'trip' : 'trips'}',
                    style: const TextStyle(
                      color: Color(0xFFCFD9D2),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _DistanceChart(values: chartValues, labels: chartLabels),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    changePercent == null
                        ? Icons.remove_circle_outline_rounded
                        : changePercent >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                    size: 16,
                    color: changePercent == null
                        ? const Color(0xFFB8C7BD)
                        : changePercent >= 0
                            ? BeaconColors.lime
                            : BeaconColors.coral,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      changePercent == null
                          ? 'No previous period data to compare yet'
                          : '${changePercent >= 0 ? '+' : ''}$changePercent% vs previous ${_period.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Period summary',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${currentTrips.length} ${currentTrips.length == 1 ? 'trip' : 'trips'}',
              style: const TextStyle(
                color: BeaconColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SurfacePanel(
          padding: 14,
          child: Column(
            children: [
              _InsightRow(
                icon: Icons.route_rounded,
                color: BeaconColors.blue,
                title: totalDistance == 0
                    ? 'No movement recorded'
                    : 'Movement total',
                detail: totalDistance == 0
                    ? 'Start a tracked trip to build your first summary.'
                    : 'You covered ${totalDistance.toStringAsFixed(1)} km across ${currentTrips.length} trip${currentTrips.length == 1 ? '' : 's'} this ${_period.toLowerCase()}.',
              ),
              const Divider(height: 18, color: BeaconColors.line),
              _InsightRow(
                icon: Icons.local_fire_department_rounded,
                color: BeaconColors.coral,
                title: busiestDay == null
                    ? 'No active day yet'
                    : 'Most active day',
                detail: busiestDay == null
                    ? 'A day-by-day pattern will appear after trips are recorded.'
                    : '${_weekdayName(busiestDay.key.weekday)} · ${(busiestDay.value / 1000).toStringAsFixed(1)} km.',
              ),
              const Divider(height: 18, color: BeaconColors.line),
              _InsightRow(
                icon: Icons.speed_rounded,
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

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    const periods = <(String, IconData)>[
      ('Week', Icons.view_week_rounded),
      ('Month', Icons.calendar_month_rounded),
      ('Year', Icons.timeline_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final (label, icon) in periods)
            Expanded(
              child: _PeriodButton(
                label: label,
                icon: icon,
                selected: selectedPeriod == label,
                onTap: () => onPeriodChanged(label),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? BeaconColors.ink : BeaconColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label view',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE6ECE4) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.changePercent});

  final int changePercent;

  @override
  Widget build(BuildContext context) {
    final positive = changePercent >= 0;
    final color = positive ? BeaconColors.lime : const Color(0xFFFFB0A3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.north_east_rounded : Icons.south_east_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${positive ? '+' : ''}$changePercent%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      height: 116,
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        height: maximum == 0
                            ? 3
                            : 8 + values[index] / maximum * 64,
                        width: 18,
                        decoration: BoxDecoration(
                          color: _chartBarColor(index, values[index], maximum),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5),
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

Color _chartBarColor(int index, double value, double maximum) {
  if (maximum == 0) return const Color(0xFF536B60);
  if (value == maximum) return BeaconColors.lime;
  return switch (index % 3) {
    0 => const Color(0xFF75B6C5),
    1 => const Color(0xFFE98F79),
    _ => const Color(0xFFA8B875),
  };
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
