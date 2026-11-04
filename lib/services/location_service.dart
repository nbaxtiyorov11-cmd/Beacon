import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'trip_service.dart';

class LocationService {
  static const maximumAcceptedAccuracyMeters = 50.0;

  LocationService({GeolocatorPlatform? geolocator})
      : _geolocator = geolocator ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _geolocator;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;

  bool _trackingEnabled = false;
  Position? _lastKnownPosition;
  Position? _previousTrackedPosition;
  DateTime? _trackingStartedAt;
  DateTime? _trackingResumedAt;
  Duration _trackedDuration = Duration.zero;
  double _trackedDistanceMeters = 0;
  bool _nextPositionStartsSegment = true;
  final Set<int> _trackingSegmentStartIndices = <int>{};

  bool get trackingEnabled => _trackingEnabled;
  bool get hasActiveTrip => _trackingStartedAt != null;
  Position? get lastKnownPosition => _lastKnownPosition;
  DateTime? get trackingStartedAt => _trackingStartedAt;
  Duration get trackingDuration {
    final currentSegment = _trackingEnabled && _trackingResumedAt != null
        ? DateTime.now().difference(_trackingResumedAt!)
        : Duration.zero;
    return _trackedDuration + currentSegment;
  }

  double get trackedDistanceMeters => _trackedDistanceMeters;
  List<Position> get trackedPositions => List.unmodifiable(_trackedPositions);
  List<int> get trackingSegmentStartIndices =>
      List.unmodifiable(_trackingSegmentStartIndices);
  Stream<Position> get positionStream => _positionController.stream;
  final List<Position> _trackedPositions = <Position>[];

  Future<bool> startTracking() async {
    if (_trackingEnabled) return true;
    if (hasActiveTrip) return resumeTracking();
    if (!await _hasLocationPermission()) return false;

    _trackedPositions.clear();
    _trackingSegmentStartIndices.clear();
    _previousTrackedPosition = null;
    _nextPositionStartsSegment = true;
    _trackedDistanceMeters = 0;
    _trackingStartedAt = DateTime.now();
    _trackedDuration = Duration.zero;
    _startPositionUpdates();
    return true;
  }

  Future<bool> resumeTracking() async {
    if (_trackingEnabled) return true;
    if (!hasActiveTrip) return startTracking();
    if (!await _hasLocationPermission()) return false;

    _startPositionUpdates();
    return true;
  }

  void _startPositionUpdates() {
    _trackingEnabled = true;
    _trackingResumedAt = DateTime.now();
    _subscription =
        _geolocator
        .getPositionStream(locationSettings: _trackingLocationSettings)
        .listen(_recordPosition);
    unawaited(_requestInitialPosition());
  }

  Future<void> _requestInitialPosition() async {
    try {
      final current = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _recordPosition(current);
    } catch (_) {
      // The position stream can still provide a fix if this one-shot times out.
    }
  }

  LocationSettings get _trackingLocationSettings {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  Future<Position?> getCurrentPosition() async {
    if (!await _hasLocationPermission()) return null;
    try {
      final position = await _geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return _isUsablePosition(position) ? position : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasLocationPermission() async {
    if (!await _geolocator.isLocationServiceEnabled()) return false;

    var permission = await _geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return false;
    }

    var handlerPermission = await Permission.locationWhenInUse.status;
    if (!handlerPermission.isGranted) {
      handlerPermission = await Permission.locationWhenInUse.request();
    }
    return handlerPermission.isGranted;
  }

  void _recordPosition(Position position) {
    if (!_trackingEnabled || !_isUsablePosition(position)) return;
    final lastPosition =
        _trackedPositions.isEmpty ? null : _trackedPositions.last;
    if (lastPosition != null &&
        !position.timestamp.isAfter(lastPosition.timestamp)) {
      return;
    }

    final previous = _previousTrackedPosition;
    final startsSegment = _nextPositionStartsSegment ||
        previous == null ||
        !TripService.samplesAreContinuous(previous, position);
    if (startsSegment) {
      _trackingSegmentStartIndices.add(_trackedPositions.length);
    } else {
      _trackedDistanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
    }
    _trackedPositions.add(position);
    _previousTrackedPosition = position;
    _nextPositionStartsSegment = false;
    _lastKnownPosition = position;
    _positionController.add(position);
  }

  bool _isUsablePosition(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.accuracy.isFinite &&
        position.accuracy <= maximumAcceptedAccuracyMeters &&
        age <= const Duration(seconds: 20) &&
        age >= const Duration(seconds: -5);
  }

  Future<void> pauseTracking() async {
    if (_trackingEnabled && _trackingResumedAt != null) {
      _trackedDuration += DateTime.now().difference(_trackingResumedAt!);
    }
    _trackingResumedAt = null;
    _trackingEnabled = false;
    _previousTrackedPosition = null;
    _nextPositionStartsSegment = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> stopTracking() async {
    await pauseTracking();
    _trackedPositions.clear();
    _trackingSegmentStartIndices.clear();
    _previousTrackedPosition = null;
    _nextPositionStartsSegment = true;
    _trackingStartedAt = null;
    _trackedDuration = Duration.zero;
    _trackedDistanceMeters = 0;
  }

  String get lastLocationLabel {
    if (_lastKnownPosition == null) {
      return 'Location unavailable';
    }

    return '${_lastKnownPosition!.latitude.toStringAsFixed(4)}, '
        '${_lastKnownPosition!.longitude.toStringAsFixed(4)}';
  }
}
