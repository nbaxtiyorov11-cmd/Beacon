import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class TripLocation {
  const TripLocation({
    required this.latitude,
    required this.longitude,
    this.segmentStart = false,
  });

  final double latitude;
  final double longitude;
  final bool segmentStart;
}

class SafePlace {
  const SafePlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 120,
    this.totalVisitSeconds = 0,
    this.lastVisitSeconds = 0,
    this.lastVisitedAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int totalVisitSeconds;
  final int lastVisitSeconds;
  final DateTime? lastVisitedAt;

  bool contains(Position position) =>
      Geolocator.distanceBetween(
        latitude,
        longitude,
        position.latitude,
        position.longitude,
      ) <=
      radiusMeters;
}

class SafePlaceVisit {
  const SafePlaceVisit({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  final String id;
  final String placeId;
  final String placeName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;

  int secondsOverlapping(DateTime start, DateTime end) {
    final overlapStart = startedAt.isAfter(start) ? startedAt : start;
    final overlapEnd = endedAt.isBefore(end) ? endedAt : end;
    if (!overlapEnd.isAfter(overlapStart)) return 0;
    return overlapEnd.difference(overlapStart).inSeconds;
  }
}

class TripEntry {
  TripEntry({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.points,
    required this.distanceMeters,
    required this.averageSpeedKmh,
    this.name,
    this.movingSeconds,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<TripLocation> points;
  final double distanceMeters;
  final double averageSpeedKmh;
  final String? name;
  final double? movingSeconds;

  String get title {
    final customName = name?.trim();
    if (customName != null && customName.isNotEmpty) return customName;
    return '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')} - ${endedAt.hour.toString().padLeft(2, '0')}:${endedAt.minute.toString().padLeft(2, '0')}';
  }

  double get totalMinutes => movingSeconds == null
      ? endedAt.difference(startedAt).inMinutes.toDouble()
      : movingSeconds! / 60;
}

class TripService {
  static const maximumContinuousSampleGap = Duration(seconds: 20);
  static const maximumAcceptedAccuracyMeters = 50.0;
  static const maximumPlausibleSpeedMetersPerSecond = 45.0;
  static const minimumReliableDisplacementMeters = 3.0;

  final List<TripEntry> _trips = <TripEntry>[];

  List<TripEntry> get trips => List.unmodifiable(_trips);

  void replaceTrips(Iterable<TripEntry> trips) {
    _trips
      ..clear()
      ..addAll(trips);
  }

  void addTrip(TripEntry trip) {
    _trips.insert(0, trip);
  }

  static bool samplesAreContinuous(Position previous, Position current) {
    final gap = current.timestamp.difference(previous.timestamp);
    return gap > Duration.zero &&
        gap <= maximumContinuousSampleGap &&
        isPlausibleMovement(previous, current);
  }

  static bool isPlausibleMovement(Position previous, Position current) {
    final seconds =
        current.timestamp.difference(previous.timestamp).inMicroseconds /
            Duration.microsecondsPerSecond;
    if (seconds <= 0) return false;
    final distanceMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    return distanceMeters <= maximumPlausibleSpeedMetersPerSecond * seconds;
  }

  static bool isReliableDisplacement(Position previous, Position current) {
    final distanceMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final accuracyThreshold = (previous.accuracy + current.accuracy) * 0.25;
    return distanceMeters >=
        math.max(minimumReliableDisplacementMeters, accuracyThreshold);
  }

  bool _isValidPosition(Position position) =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude >= -180 &&
      position.longitude <= 180 &&
      position.accuracy.isFinite &&
      position.accuracy >= 0 &&
      position.accuracy <= maximumAcceptedAccuracyMeters;

  TripEntry? recordTripFromPositions(
    List<Position> positions, {
    String? name,
    Iterable<int> segmentStartIndices = const [],
    bool addToHistory = true,
  }) {
    if (positions.isEmpty) return null;

    final explicitSegmentStarts = segmentStartIndices.toSet();
    final validPositions = <({Position position, bool segmentStart})>[];
    for (var index = 0; index < positions.length; index++) {
      final position = positions[index];
      if (!_isValidPosition(position)) continue;
      if (validPositions.isEmpty) {
        validPositions.add((position: position, segmentStart: true));
        continue;
      }

      final previous = validPositions.last.position;
      final gap = position.timestamp.difference(previous.timestamp);
      if (!explicitSegmentStarts.contains(index) && gap <= Duration.zero) {
        continue;
      }
      final startsSegment = explicitSegmentStarts.contains(index) ||
          gap > maximumContinuousSampleGap;
      if (!startsSegment) {
        if (!isPlausibleMovement(previous, position) ||
            !isReliableDisplacement(previous, position)) {
          continue;
        }
      }
      validPositions.add((position: position, segmentStart: startsSegment));
    }
    if (validPositions.isEmpty) return null;
    if (validPositions.length < 2) {
      final point = validPositions.first.position;
      final trip = TripEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        startedAt: point.timestamp,
        endedAt: point.timestamp,
        points: [
          TripLocation(
            latitude: point.latitude,
            longitude: point.longitude,
            segmentStart: true,
          ),
        ],
        distanceMeters: 0,
        averageSpeedKmh: 0,
        name: name,
        movingSeconds: 0,
      );
      if (addToHistory) _trips.insert(0, trip);
      return trip;
    }

    final points = <TripLocation>[];
    final startedAt = validPositions.first.position.timestamp;
    final endedAt = validPositions.last.position.timestamp;
    double totalDistance = 0;
    double movingSeconds = 0;
    for (var index = 0; index < validPositions.length; index++) {
      final position = validPositions[index].position;
      final segmentStart = index == 0 ||
          validPositions[index].segmentStart ||
          !samplesAreContinuous(validPositions[index - 1].position, position);
      points.add(TripLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        segmentStart: segmentStart,
      ));
      if (segmentStart) continue;

      movingSeconds += position.timestamp
          .difference(validPositions[index - 1].position.timestamp)
          .inSeconds;
      totalDistance += _distanceBetween(
        validPositions[index - 1].position.latitude,
        validPositions[index - 1].position.longitude,
        position.latitude,
        position.longitude,
      );
    }

    final averageSpeed = movingSeconds > 0
        ? (totalDistance / 1000) / (movingSeconds / 3600)
        : 0.0;

    final trip = TripEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: startedAt,
      endedAt: endedAt,
      points: points,
      distanceMeters: totalDistance,
      averageSpeedKmh: averageSpeed,
      name: name,
      movingSeconds: movingSeconds,
    );

    if (addToHistory) _trips.insert(0, trip);
    return trip;
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
}
