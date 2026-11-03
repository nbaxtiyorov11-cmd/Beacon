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
  double _trackedDistanceMeters = 0;

  bool get trackingEnabled => _trackingEnabled;
  Position? get lastKnownPosition => _lastKnownPosition;
  DateTime? get trackingStartedAt => _trackingStartedAt;
  double get trackedDistanceMeters => _trackedDistanceMeters;
  List<Position> get trackedPositions => List.unmodifiable(_trackedPositions);
  Stream<Position> get positionStream => _positionController.stream;
  final List<Position> _trackedPositions = <Position>[];

  Future<bool> startTracking() async {
    if (!await _hasLocationPermission()) return false;

    _trackingEnabled = true;
    _trackedPositions.clear();
    _previousTrackedPosition = null;
    _trackedDistanceMeters = 0;
    _trackingStartedAt = DateTime.now();

    _subscription ??= _geolocator
        .getPositionStream(locationSettings: _trackingLocationSettings)
        .listen(_recordPosition);

    unawaited(_requestInitialPosition());
    return true;
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
    final previous = _previousTrackedPosition;
    if (previous != null && !position.timestamp.isAfter(previous.timestamp)) {
      return;
    }
    if (previous != null &&
        TripService.samplesAreContinuous(previous, position)) {
      _trackedDistanceMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
    }
    _trackedPositions.add(position);
    _previousTrackedPosition = position;
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

  Future<void> stopTracking() async {
    _trackingEnabled = false;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  String get lastLocationLabel {
    if (_lastKnownPosition == null) {
      return 'Location unavailable';
    }

    return '${_lastKnownPosition!.latitude.toStringAsFixed(4)}, '
        '${_lastKnownPosition!.longitude.toStringAsFixed(4)}';
  }
}
