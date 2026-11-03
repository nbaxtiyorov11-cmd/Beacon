import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.trackingEnabled,
    required this.onTrackingChanged,
    required this.userName,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenEmergency,
    required this.trips,
    required this.liveTrackingDistanceMeters,
    required this.trackingStartedAt,
    this.pendingNotificationCount = 0,
    this.locationLabel,
    super.key,
  });

  final bool trackingEnabled;
  final ValueChanged<bool> onTrackingChanged;
  final String? userName;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenEmergency;
  final List<TripEntry> trips;
  final double liveTrackingDistanceMeters;
  final DateTime? trackingStartedAt;
  final int pendingNotificationCount;
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayTrips = trips
        .where((trip) => _sameDate(trip.startedAt, now))
        .toList()
      ..sort((first, second) => second.startedAt.compareTo(first.startedAt));
    final todayDistance = todayTrips.fold<double>(
          0,
          (total, trip) => total + trip.distanceMeters,
        ) +
        (trackingEnabled ? liveTrackingDistanceMeters : 0);
    final todayDuration = Duration(
          minutes: todayTrips.fold<int>(
            0,
            (total, trip) => total + trip.totalMinutes.round(),
          ),
        ) +
        (trackingEnabled && trackingStartedAt != null
            ? now.difference(trackingStartedAt!)
            : Duration.zero);
    final todayTripCount = todayTrips.length + (trackingEnabled ? 1 : 0);
    final weeklyDistance = _distancesForDays(trips, now, 7);
    if (trackingEnabled && weeklyDistance.isNotEmpty) {
      weeklyDistance[weeklyDistance.length - 1] += liveTrackingDistanceMeters;
    }
    final currentWeekTotal =
        weeklyDistance.fold<double>(0, (sum, value) => sum + value);
    final previousWeekTotal = trips.where((trip) {
      final age = _calendarDayDifference(now, trip.startedAt);
      return age >= 7 && age < 14;
    }).fold<double>(0, (sum, trip) => sum + trip.distanceMeters);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BeaconColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: BeaconColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.radar, color: BeaconColors.lime, size: 21),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BEACON',
                    style: TextStyle(
                      color: BeaconColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'MOVEMENT JOURNAL',
                    style: TextStyle(
                      color: BeaconColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Notifications',
                style: IconButton.styleFrom(foregroundColor: BeaconColors.ink),
                onPressed: onOpenNotifications,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (pendingNotificationCount > 0)
                      Positioned(
                        right: -7,
                        top: -6,
                        child: Container(
                          key: const ValueKey('pending-notification-count'),
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: BeaconColors.coral,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            pendingNotificationCount > 99
                                ? '99+'
                                : '$pendingNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Your profile',
                onPressed: onOpenProfile,
                icon: CircleAvatar(
                  radius: 17,
                  backgroundColor: BeaconColors.lime,
                  foregroundColor: BeaconColors.ink,
                  child: Text(
                    (userName?.trim().isNotEmpty == true
                            ? userName!.trim()[0]
                            : 'A')
                        .toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 21),
        Text(
          _formatDateLabel(now).toUpperCase(),
          style: const TextStyle(
            color: BeaconColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_greeting(now)}, ${_firstName(userName)}.',
          style: const TextStyle(
            color: BeaconColors.ink,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _TrackingPanel(
          trackingEnabled: trackingEnabled,
          onTrackingChanged: onTrackingChanged,
          locationLabel: locationLabel,
          distanceMeters: liveTrackingDistanceMeters,
          trackingStartedAt: trackingStartedAt,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                label: 'DISTANCE',
                value: _formatDistance(todayDistance),
                icon: Icons.straighten_rounded,
                tint: BeaconColors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TodayMetric(
                label: 'MOVING',
                value: _formatDuration(todayDuration),
                icon: Icons.schedule_rounded,
                tint: BeaconColors.coral,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TodayMetric(
                label: 'TRIPS',
                value: '$todayTripCount',
                icon: Icons.route_outlined,
                tint: BeaconColors.forest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Last 7 days',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(currentWeekTotal / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(
                color: BeaconColors.forest,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _WeeklyMovement(
          values: weeklyDistance,
          currentTotal: currentWeekTotal,
          previousTotal: previousWeekTotal,
          today: now,
        ),
        const SizedBox(height: 25),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Today’s movement',
                style: TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$todayTripCount ${todayTripCount == 1 ? 'trip' : 'trips'}',
              style: const TextStyle(color: BeaconColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: BeaconColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (trackingEnabled)
                _MovementRow(
                  title: 'Tracking now',
                  detail: locationLabel ?? 'Waiting for a location update',
                  trailing: _formatDistance(liveTrackingDistanceMeters),
                  icon: Icons.my_location_rounded,
                  tint: BeaconColors.forest,
                  isLive: true,
                ),
              for (var index = 0; index < todayTrips.length; index++) ...[
                if (index > 0 || trackingEnabled)
                  const Divider(
                      height: 1, indent: 58, color: BeaconColors.line),
                _MovementRow(
                  title: todayTrips[index].name?.trim().isNotEmpty == true
                      ? todayTrips[index].name!.trim()
                      : 'Recorded trip',
                  detail:
                      '${_formatClock(todayTrips[index].startedAt)} · ${_formatDuration(Duration(minutes: todayTrips[index].totalMinutes.round()))}',
                  trailing: _formatDistance(todayTrips[index].distanceMeters),
                  icon: Icons.route_outlined,
                  tint: BeaconColors.blue,
                ),
              ],
              if (!trackingEnabled && todayTrips.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.directions_walk, color: BeaconColors.muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No trips recorded today. Start tracking to build your daily summary.',
                          style: TextStyle(
                            color: BeaconColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({
    required this.trackingEnabled,
    required this.onTrackingChanged,
    required this.distanceMeters,
    required this.trackingStartedAt,
    this.locationLabel,
  });

  final bool trackingEnabled;
  final ValueChanged<bool> onTrackingChanged;
  final String? locationLabel;
  final double distanceMeters;
  final DateTime? trackingStartedAt;

  @override
  Widget build(BuildContext context) {
    final duration = trackingStartedAt == null
        ? Duration.zero
        : DateTime.now().difference(trackingStartedAt!);
    return Container(
      decoration: BoxDecoration(
        color: BeaconColors.ink,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle,
                  size: 9,
                  color:
                      trackingEnabled ? BeaconColors.lime : BeaconColors.coral),
              const SizedBox(width: 7),
              Text(
                trackingEnabled ? 'TRACKING LIVE' : 'TRACKING PAUSED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateLabel(DateTime.now()),
                style: const TextStyle(color: Color(0xFFB8C7BD), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            trackingEnabled
                ? _formatDistance(distanceMeters)
                : 'Ready when you are',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trackingEnabled
                ? '${_formatDuration(duration)} active · ${locationLabel ?? 'Waiting for GPS'}'
                : 'Movement recording is paused',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFB8C7BD), fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 38,
            child: FilledButton.icon(
              onPressed: () => onTrackingChanged(!trackingEnabled),
              style: FilledButton.styleFrom(
                backgroundColor: BeaconColors.lime,
                foregroundColor: BeaconColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: Icon(trackingEnabled ? Icons.pause : Icons.play_arrow,
                  size: 17),
              label:
                  Text(trackingEnabled ? 'Pause tracking' : 'Start tracking'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.fromLTRB(10, 11, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                color: BeaconColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _WeeklyMovement extends StatelessWidget {
  const _WeeklyMovement({
    required this.values,
    required this.currentTotal,
    required this.previousTotal,
    required this.today,
  });

  final List<double> values;
  final double currentTotal;
  final double previousTotal;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<double>(
        0, (maxValue, value) => value > maxValue ? value : maxValue);
    final comparison = previousTotal == 0
        ? null
        : ((currentTotal - previousTotal) / previousTotal * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 90,
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
                              duration: const Duration(milliseconds: 250),
                              height:
                                  peak == 0 ? 3 : 6 + values[index] / peak * 55,
                              width: 18,
                              decoration: BoxDecoration(
                                color: index == values.length - 1
                                    ? BeaconColors.coral
                                    : BeaconColors.blue.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _weekdayInitial(today
                              .subtract(
                                  Duration(days: values.length - index - 1))
                              .weekday),
                          style: const TextStyle(
                              color: BeaconColors.muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.insights_outlined,
                  size: 16, color: BeaconColors.forest),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  comparison == null
                      ? 'Your previous-week comparison will appear after 7 days of data.'
                      : '${comparison >= 0 ? '+' : ''}$comparison% vs. the previous 7 days',
                  maxLines: 2,
                  style: const TextStyle(
                      color: BeaconColors.muted, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.title,
    required this.detail,
    required this.trailing,
    required this.icon,
    required this.tint,
    this.isLive = false,
  });

  final String title;
  final String detail;
  final String trailing;
  final IconData icon;
  final Color tint;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: tint, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: BeaconColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: BeaconColors.muted, fontSize: 11)),
              ],
            ),
          ),
          if (isLive) ...[
            const SizedBox(width: 6),
            const Icon(Icons.circle, size: 7, color: BeaconColors.forest),
          ],
          const SizedBox(width: 8),
          Text(trailing,
              style: const TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

int _calendarDayDifference(DateTime today, DateTime value) {
  final currentDay = DateTime(today.year, today.month, today.day);
  final valueDay = DateTime(value.year, value.month, value.day);
  return currentDay.difference(valueDay).inDays;
}

List<double> _distancesForDays(
    List<TripEntry> trips, DateTime today, int days) {
  return List.generate(days, (index) {
    final date = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - index - 1));
    return trips
        .where((trip) => _sameDate(trip.startedAt, date))
        .fold<double>(0, (sum, trip) => sum + trip.distanceMeters);
  });
}

String _firstName(String? name) {
  final clean = name?.trim() ?? '';
  return clean.isEmpty ? 'there' : clean.split(RegExp(r'\s+')).first;
}

String _greeting(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _formatDateLabel(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _weekdayInitial(int weekday) {
  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return days[weekday - 1];
}

String _formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${meters.round()} m';

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${duration.inMinutes} min';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
