import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.trackingEnabled,
    required this.onTrackingChanged,
    required this.userName,
    required this.onOpenChats,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.onOpenEmergency,
    required this.trips,
    required this.liveTrackingDistanceMeters,
    required this.trackingStartedAt,
    this.trackingSessionActive = false,
    this.trackingDuration = Duration.zero,
    this.onEndTrip,
    this.pendingNotificationCount = 0,
    this.locationLabel,
    super.key,
  });

  final bool trackingEnabled;
  final ValueChanged<bool> onTrackingChanged;
  final String? userName;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenEmergency;
  final List<TripEntry> trips;
  final double liveTrackingDistanceMeters;
  final DateTime? trackingStartedAt;
  final bool trackingSessionActive;
  final Duration trackingDuration;
  final VoidCallback? onEndTrip;
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
        (trackingSessionActive ? liveTrackingDistanceMeters : 0);
    final todayDuration = Duration(
          minutes: todayTrips.fold<int>(
            0,
            (total, trip) => total + trip.totalMinutes.round(),
          ),
        ) +
        (trackingSessionActive ? trackingDuration : Duration.zero);
    final todayTripCount = todayTrips.length + (trackingSessionActive ? 1 : 0);
    final weeklyDistance = _distancesForDays(trips, now, 7);
    if (trackingSessionActive && weeklyDistance.isNotEmpty) {
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
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Chats',
                  style: IconButton.styleFrom(
                    foregroundColor: BeaconColors.ink,
                  ),
                  onPressed: onOpenChats,
                  icon: const Icon(Icons.forum_rounded),
                ),
                const Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: BeaconColors.ink,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.radar,
                              color: BeaconColors.lime,
                              size: 21,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Column(
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
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      style: IconButton.styleFrom(
                        foregroundColor: BeaconColors.ink,
                      ),
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
                                key: const ValueKey(
                                    'pending-notification-count'),
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 21),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE7EEE9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: BeaconColors.forest,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateLabel(now).toUpperCase(),
                style: const TextStyle(
                  color: BeaconColors.forest,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_greeting(now)}, ${_firstName(userName)}.',
          style: const TextStyle(
            color: BeaconColors.ink,
            fontSize: 31,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Your movement, at a glance.',
          style: TextStyle(color: BeaconColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _TrackingPanel(
          trackingEnabled: trackingEnabled,
          trackingSessionActive: trackingSessionActive,
          onTrackingChanged: onTrackingChanged,
          onEndTrip: onEndTrip,
          locationLabel: locationLabel,
          distanceMeters: liveTrackingDistanceMeters,
          trackingStartedAt: trackingStartedAt,
          trackingDuration: trackingDuration,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEE9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(currentWeekTotal / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: BeaconColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: BeaconColors.coral.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.route_rounded,
                color: BeaconColors.coral,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
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
              style: const TextStyle(
                color: BeaconColors.forest,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
    required this.trackingSessionActive,
    required this.onTrackingChanged,
    required this.onEndTrip,
    required this.distanceMeters,
    required this.trackingStartedAt,
    required this.trackingDuration,
    this.locationLabel,
  });

  final bool trackingEnabled;
  final bool trackingSessionActive;
  final ValueChanged<bool> onTrackingChanged;
  final VoidCallback? onEndTrip;
  final String? locationLabel;
  final double distanceMeters;
  final DateTime? trackingStartedAt;
  final Duration trackingDuration;

  @override
  Widget build(BuildContext context) {
    final duration = trackingDuration == Duration.zero &&
            trackingEnabled &&
            trackingStartedAt != null
        ? DateTime.now().difference(trackingStartedAt!)
        : trackingDuration;
    final statusLabel = trackingEnabled ? 'TRACKING LIVE' : 'TRACKING PAUSED';
    return Container(
      decoration: BoxDecoration(
        color: trackingEnabled ? BeaconColors.ink : BeaconColors.forest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: trackingEnabled
                      ? BeaconColors.lime.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trackingEnabled
                          ? Icons.radar_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 14,
                      color: trackingEnabled
                          ? BeaconColors.lime
                          : const Color(0xFFD8E1DB),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: trackingEnabled
                            ? BeaconColors.lime
                            : const Color(0xFFD8E1DB),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _formatDateLabel(DateTime.now()),
                style: const TextStyle(color: Color(0xFFCFD9D2), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            trackingSessionActive
                ? _formatDistance(distanceMeters)
                : 'Ready when you are',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trackingSessionActive
                ? trackingEnabled
                    ? '${_formatDuration(duration)} active · ${locationLabel ?? 'Waiting for GPS'}'
                    : '${_formatDuration(duration)} active · Trip paused'
                : 'Movement recording is paused',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFCFD9D2), fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (trackingSessionActive && onEndTrip != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final primaryAction = SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const ValueKey('tracking-session-action'),
                    onPressed: () => onTrackingChanged(!trackingEnabled),
                    style: FilledButton.styleFrom(
                      backgroundColor: BeaconColors.lime,
                      foregroundColor: BeaconColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: Icon(
                      trackingEnabled
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 19,
                    ),
                    label: Text(
                      trackingEnabled ? 'Pause trip' : 'Continue trip',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
                final endAction = SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    key: const ValueKey('end-trip-action'),
                    onPressed: onEndTrip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFA092),
                      side: const BorderSide(color: Color(0xFFB9685F)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('End trip'),
                  ),
                );

                if (constraints.maxWidth < 280) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      primaryAction,
                      const SizedBox(height: 9),
                      endAction,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 6, child: primaryAction),
                    const SizedBox(width: 9),
                    Expanded(flex: 4, child: endAction),
                  ],
                );
              },
            ),
          ] else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => onTrackingChanged(true),
                style: FilledButton.styleFrom(
                  backgroundColor: BeaconColors.lime,
                  foregroundColor: BeaconColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start tracking'),
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
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                  color: BeaconColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
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
    final peakValue = peak / 1000;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BeaconColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily distance',
                  style: TextStyle(
                    color: BeaconColors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                peakValue == 0
                    ? 'No trips yet'
                    : 'Peak ${peakValue.toStringAsFixed(1)} km',
                style: const TextStyle(
                  color: BeaconColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                                  peak == 0 ? 3 : 7 + values[index] / peak * 56,
                              width: 19,
                              decoration: BoxDecoration(
                                color: _weeklyBarColor(
                                  index,
                                  values[index],
                                  peak,
                                  index == values.length - 1,
                                ),
                                borderRadius: BorderRadius.circular(5),
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

Color _weeklyBarColor(
  int index,
  double value,
  double peak,
  bool isToday,
) {
  if (peak == 0) return const Color(0xFFDCE4DD);
  if (isToday) return BeaconColors.coral;
  if (value == peak) return BeaconColors.forest;
  return switch (index % 3) {
    0 => BeaconColors.blue,
    1 => const Color(0xFF9BB57A),
    _ => const Color(0xFF8DA8A1),
  };
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
