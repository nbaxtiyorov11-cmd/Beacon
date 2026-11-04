import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../auth/auth_service.dart';
import '../pages/activity_page.dart';
import '../pages/chats_page.dart';
import '../pages/emergency_page.dart';
import '../pages/family_page.dart';
import '../pages/home_page.dart';
import '../pages/insights_page.dart';
import '../pages/map_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/trip_service.dart';
import '../theme/beacon_theme.dart';

class BeaconShell extends StatefulWidget {
  const BeaconShell({
    required this.user,
    required this.authService,
    required this.locationService,
    required this.tripService,
    required this.firestoreService,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final LocationService locationService;
  final TripService tripService;
  final FirestoreService firestoreService;

  @override
  State<BeaconShell> createState() => _BeaconShellState();
}

class _BeaconShellState extends State<BeaconShell> {
  int _selectedIndex = 0;
  bool _trackingEnabled = false;
  bool _trackingSessionActive = false;
  UserSettings _userSettings = const UserSettings();
  StreamSubscription<List<TripEntry>>? _tripSubscription;
  StreamSubscription<List<FamilyInvitation>>? _invitationSubscription;
  StreamSubscription<List<SafePlace>>? _safePlaceSubscription;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<String>? _messagingTokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
  Timer? _trackingTimer;
  DateTime? _lastFamilyLocationWrite;
  int _trackingSaveGeneration = 0;
  int _pendingInvitationCount = 0;
  List<SafePlace> _safePlaces = const [];
  String? _activeSafePlaceId;
  double _activeSafePlaceSeconds = 0;
  Position? _previousSafePlacePosition;
  String? _messagingToken;
  bool _configuringMessaging = false;

  @override
  void initState() {
    super.initState();
    _trackingEnabled = widget.locationService.trackingEnabled;
    _trackingSessionActive = widget.locationService.hasActiveTrip;
    _loadUserData();
    _watchTrips();
    _watchIncomingInvitations();
    _watchSafePlaces();
    _locationSubscription =
        widget.locationService.positionStream.listen((position) {
      _updateSafePlaceVisit(position);
      if (_userSettings.familySharing) {
        _shareFamilyLocation(position);
      }
      if (mounted) setState(() {});
    });
    if (_trackingEnabled) _startTrackingClock();
  }

  Future<void> _loadUserData() async {
    final settings =
        await widget.firestoreService.fetchUserSettings(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _userSettings = settings;
      _trackingEnabled = widget.locationService.trackingEnabled;
    });
    unawaited(_configureMessaging(settings.notifications));
  }

  void _watchTrips() {
    var syncedInitialStats = false;
    _tripSubscription =
        widget.firestoreService.watchTrips(widget.user.uid).listen(
      (trips) {
        widget.tripService.replaceTrips(trips);
        if (!syncedInitialStats && trips.isNotEmpty) {
          syncedInitialStats = true;
          unawaited(widget.firestoreService
              .syncPublicActivityStats(widget.user.uid, trips));
        }
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        widget.firestoreService.status.value = 'Trip updates unavailable';
      },
    );
  }

  void _watchIncomingInvitations() {
    _invitationSubscription = widget.firestoreService
        .watchIncomingFamilyInvitations(widget.user.uid)
        .listen((invitations) {
      if (!mounted) return;
      setState(() => _pendingInvitationCount = invitations.length);
    });
  }

  void _watchSafePlaces() {
    _safePlaceSubscription =
        widget.firestoreService.watchSafePlaces(widget.user.uid).listen(
      (places) {
        _safePlaces = places;
        if (_activeSafePlaceId != null &&
            !places.any((place) => place.id == _activeSafePlaceId)) {
          _finishSafePlaceVisit(
            _previousSafePlacePosition?.timestamp ?? DateTime.now(),
          );
        }
        if (mounted) setState(() {});
      },
      onError: (Object error) =>
          debugPrint('Could not load safe places: $error'),
    );
  }

  SafePlace? _safePlaceContaining(Position? position) {
    if (position == null) return null;
    for (final place in _safePlaces) {
      if (place.contains(position)) return place;
    }
    return null;
  }

  void _updateSafePlaceVisit(Position position) {
    final previous = _previousSafePlacePosition;
    final place = _safePlaceContaining(position);
    final continuous = previous != null &&
        TripService.samplesAreContinuous(previous, position);

    if (_activeSafePlaceId != null &&
        (_activeSafePlaceId != place?.id || !continuous)) {
      _finishSafePlaceVisit(previous?.timestamp ?? position.timestamp);
    }

    if (place != null) {
      if (_activeSafePlaceId == null) {
        _activeSafePlaceId = place.id;
        _activeSafePlaceSeconds = 0;
      } else if (continuous) {
        _activeSafePlaceSeconds +=
            position.timestamp.difference(previous.timestamp).inSeconds;
      }
    }

    _previousSafePlacePosition = position;
  }

  void _finishSafePlaceVisit(DateTime visitedAt) {
    final placeId = _activeSafePlaceId;
    final visitSeconds = _activeSafePlaceSeconds.round();
    if (placeId != null &&
        visitSeconds > 0 &&
        _safePlaces.any((place) => place.id == placeId)) {
      unawaited(_saveSafePlaceVisit(
        placeId: placeId,
        visitSeconds: visitSeconds,
        visitedAt: visitedAt,
      ));
    }
    _activeSafePlaceId = null;
    _activeSafePlaceSeconds = 0;
  }

  Future<void> _saveSafePlaceVisit({
    required String placeId,
    required int visitSeconds,
    required DateTime visitedAt,
  }) async {
    try {
      await widget.firestoreService.recordSafePlaceVisit(
        userId: widget.user.uid,
        placeId: placeId,
        visitSeconds: visitSeconds,
        visitedAt: visitedAt,
      );
    } catch (error) {
      debugPrint('Could not save safe-place visit: $error');
    }
  }

  Future<void> _configureMessaging(bool enabled) async {
    if (_configuringMessaging) return;
    _configuringMessaging = true;
    try {
      final messaging = FirebaseMessaging.instance;
      if (!enabled) {
        final token = _messagingToken ?? await messaging.getToken();
        if (token != null) {
          await widget.firestoreService.removeMessagingToken(
            userId: widget.user.uid,
            token: token,
          );
        }
        _messagingToken = null;
        await _messagingTokenSubscription?.cancel();
        await _foregroundMessageSubscription?.cancel();
        await _openedMessageSubscription?.cancel();
        _messagingTokenSubscription = null;
        _foregroundMessageSubscription = null;
        _openedMessageSubscription = null;
        return;
      }

      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _saveMessagingToken(token);
      _messagingTokenSubscription ??= messaging.onTokenRefresh.listen(
        (refreshedToken) => unawaited(_saveMessagingToken(refreshedToken)),
      );
      _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
        _showForegroundInvitation,
      );
      _openedMessageSubscription ??=
          FirebaseMessaging.onMessageOpenedApp.listen(
        _openNotificationFromMessage,
      );

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _openNotificationFromMessage(initialMessage);
    } catch (error) {
      debugPrint('Could not configure push notifications: $error');
    } finally {
      _configuringMessaging = false;
    }
  }

  Future<void> _saveMessagingToken(String token) async {
    try {
      await widget.firestoreService.saveMessagingToken(
        userId: widget.user.uid,
        token: token,
      );
      _messagingToken = token;
    } catch (error) {
      debugPrint('Could not save push notification token: $error');
    }
  }

  void _showForegroundInvitation(RemoteMessage message) {
    if (message.data['type'] != 'family_invitation' || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          message.notification?.title ?? 'You have a new family request.',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: _openNotifications,
        ),
      ),
    );
  }

  void _openNotificationFromMessage(RemoteMessage message) {
    if (message.data['type'] != 'family_invitation') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openNotifications();
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    unawaited(_tripSubscription?.cancel());
    unawaited(_invitationSubscription?.cancel());
    unawaited(_safePlaceSubscription?.cancel());
    unawaited(_locationSubscription?.cancel());
    unawaited(_messagingTokenSubscription?.cancel());
    unawaited(_foregroundMessageSubscription?.cancel());
    unawaited(_openedMessageSubscription?.cancel());
    if (_userSettings.familySharing) {
      unawaited(widget.firestoreService.clearFamilyLocation(widget.user.uid));
    }
    super.dispose();
  }

  Future<void> _setTracking(bool enabled) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (enabled) {
      final started = _trackingSessionActive
          ? await widget.locationService.resumeTracking()
          : await widget.locationService.startTracking();
      if (!started && mounted) {
        messenger?.showSnackBar(
          const SnackBar(
              content:
                  Text('Location permission is required to track movement.')),
        );
        return;
      }
      _trackingSessionActive = true;
      _startTrackingClock();
      _updateTrackingState(true);
      final generation = ++_trackingSaveGeneration;
      unawaited(_saveTrackingSettings(generation));
      return;
    }

    _trackingTimer?.cancel();
    _trackingTimer = null;
    _finishSafePlaceVisit(
      _previousSafePlacePosition?.timestamp ?? DateTime.now(),
    );
    final pauseFuture = widget.locationService.pauseTracking();
    _updateTrackingState(false);
    final generation = ++_trackingSaveGeneration;
    unawaited(_finishPausingTracking(
      pause: pauseFuture,
      clearSharedLocation: _userSettings.familySharing,
      generation: generation,
    ));
  }

  Future<void> _endTrip() async {
    if (!_trackingSessionActive) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _finishSafePlaceVisit(
      _previousSafePlacePosition?.timestamp ?? DateTime.now(),
    );
    final pauseFuture = widget.locationService.pauseTracking();
    _updateTrackingState(false);
    await pauseFuture;

    final positions = widget.locationService.trackedPositions;
    final lastPosition = positions.isEmpty ? null : positions.last;
    final savedTrip = widget.tripService.recordTripFromPositions(
      positions,
      name: _safePlaceContaining(lastPosition)?.name,
      segmentStartIndices:
          widget.locationService.trackingSegmentStartIndices,
    );
    await widget.locationService.stopTracking();
    _trackingSessionActive = false;

    final generation = ++_trackingSaveGeneration;
    unawaited(_finishStoppingTracking(
      savedTrip: savedTrip,
      clearSharedLocation: _userSettings.familySharing,
      generation: generation,
      messenger: messenger,
    ));
    if (mounted) setState(() {});
  }

  void _updateTrackingState(bool enabled) {
    final nextSettings = UserSettings(
      trackingEnabled: enabled,
      approximateLocation: _userSettings.approximateLocation,
      familySharing: _userSettings.familySharing,
      notifications: _userSettings.notifications,
    );
    _userSettings = nextSettings;
    if (mounted) setState(() => _trackingEnabled = enabled);
  }

  Future<void> _saveTrackingSettings(int generation) async {
    if (generation != _trackingSaveGeneration) return;
    await widget.firestoreService
        .saveUserSettings(widget.user.uid, _userSettings);
  }

  Future<void> _finishStoppingTracking({
    required TripEntry? savedTrip,
    required bool clearSharedLocation,
    required int generation,
    required ScaffoldMessengerState? messenger,
  }) async {
    if (savedTrip != null) {
      await widget.firestoreService.saveTrip(widget.user.uid, savedTrip);
      if (mounted && generation == _trackingSaveGeneration) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Trip saved: ${(savedTrip.distanceMeters / 1000).toStringAsFixed(2)} km',
            ),
          ),
        );
      }
    }
    if (clearSharedLocation && generation == _trackingSaveGeneration) {
      await widget.firestoreService.clearFamilyLocation(widget.user.uid);
    }
    await _saveTrackingSettings(generation);
  }

  Future<void> _finishPausingTracking({
    required Future<void> pause,
    required bool clearSharedLocation,
    required int generation,
  }) async {
    await pause;
    if (clearSharedLocation && generation == _trackingSaveGeneration) {
      await widget.firestoreService.clearFamilyLocation(widget.user.uid);
    }
    await _saveTrackingSettings(generation);
  }

  void _startTrackingClock() {
    _trackingTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _shareFamilyLocation(Position position) {
    final now = DateTime.now();
    if (_lastFamilyLocationWrite != null &&
        now.difference(_lastFamilyLocationWrite!) <
            const Duration(seconds: 30)) {
      return;
    }
    _lastFamilyLocationWrite = now;
    unawaited(_saveFamilyLocation(position));
  }

  Future<void> _saveFamilyLocation(Position position) async {
    try {
      await _writeFamilyLocation(position);
    } catch (error) {
      widget.firestoreService.status.value = 'Family location update failed';
      debugPrint('Could not share family location: $error');
    }
  }

  Future<void> _writeFamilyLocation(Position position) async {
    final precision = _userSettings.approximateLocation ? 2 : 6;
    await widget.firestoreService.updateFamilyLocation(
      userId: widget.user.uid,
      latitude: double.parse(position.latitude.toStringAsFixed(precision)),
      longitude: double.parse(position.longitude.toStringAsFixed(precision)),
    );
  }

  Future<void> _setFamilySharing(bool enabled) async {
    final previousSettings = _userSettings;
    final nextSettings = UserSettings(
      trackingEnabled: _userSettings.trackingEnabled,
      approximateLocation: _userSettings.approximateLocation,
      familySharing: enabled,
      notifications: _userSettings.notifications,
    );
    _userSettings = nextSettings;
    try {
      if (enabled && _trackingEnabled) {
        final position = await widget.locationService.getCurrentPosition();
        if (position == null) {
          throw StateError('Allow location access to share with your circle.');
        }
        await _writeFamilyLocation(position);
        _lastFamilyLocationWrite = DateTime.now();
      } else if (!enabled) {
        await widget.firestoreService.clearFamilyLocation(widget.user.uid);
        _lastFamilyLocationWrite = null;
      }

      await widget.firestoreService
          .saveUserSettings(widget.user.uid, nextSettings);
      if (mounted) setState(() {});
    } catch (_) {
      _userSettings = previousSettings;
      rethrow;
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          user: widget.user,
          authService: widget.authService,
          onOpenSettings: _openSettings,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          trackingEnabled: _trackingEnabled,
          onTrackingChanged: _setTracking,
          userEmail: widget.user.email,
          userSettings: _userSettings,
          onUserSettingsChanged: (settings) async {
            final previous = _userSettings;
            _userSettings = settings;
            await widget.firestoreService
                .saveUserSettings(widget.user.uid, settings);
            if (previous.approximateLocation != settings.approximateLocation &&
                settings.familySharing &&
                _trackingEnabled) {
              final position =
                  await widget.locationService.getCurrentPosition();
              if (position != null) await _writeFamilyLocation(position);
            }
            if (previous.notifications != settings.notifications) {
              unawaited(_configureMessaging(settings.notifications));
            }
            if (mounted) setState(() {});
          },
          onLogout: _signOutFromSettings,
        ),
      ),
    );
  }

  Future<void> _signOutFromSettings() async {
    final token = _messagingToken;
    if (token != null) {
      try {
        await widget.firestoreService.removeMessagingToken(
          userId: widget.user.uid,
          token: token,
        );
      } catch (error) {
        debugPrint('Could not remove push notification token: $error');
      }
      _messagingToken = null;
    }
    await widget.authService.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          userId: widget.user.uid,
          currentUser: widget.user,
          firestoreService: widget.firestoreService,
        ),
      ),
    );
  }

  void _openChats() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatsPage(
          currentUser: widget.user,
          firestoreService: widget.firestoreService,
        ),
      ),
    );
  }

  void _openEmergency() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyPage(
          user: widget.user,
          locationService: widget.locationService,
          firestoreService: widget.firestoreService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        trackingEnabled: _trackingEnabled,
        onTrackingChanged: _setTracking,
        trackingSessionActive: _trackingSessionActive,
        userName: widget.user.displayName,
        onOpenChats: _openChats,
        onOpenProfile: _openProfile,
        onOpenNotifications: _openNotifications,
        onOpenEmergency: _openEmergency,
        pendingNotificationCount: _pendingInvitationCount,
        locationLabel: widget.locationService.lastLocationLabel,
        trips: widget.tripService.trips,
        liveTrackingDistanceMeters:
            widget.locationService.trackedDistanceMeters,
        trackingStartedAt: widget.locationService.trackingStartedAt,
        trackingDuration: widget.locationService.trackingDuration,
        onEndTrip: _endTrip,
      ),
      InsightsPage(tripService: widget.tripService),
      MapPage(
        active: _selectedIndex == 2,
        trackingEnabled: _trackingEnabled,
        userId: widget.user.uid,
        locationService: widget.locationService,
        firestoreService: widget.firestoreService,
        tripService: widget.tripService,
      ),
      FamilyPage(
        userId: widget.user.uid,
        currentUser: widget.user,
        firestoreService: widget.firestoreService,
        locationService: widget.locationService,
        familySharing: _userSettings.familySharing,
        activeSafePlaceId: _activeSafePlaceId,
        activeSafePlaceSeconds: _activeSafePlaceSeconds.round(),
        onFamilySharingChanged: _setFamilySharing,
      ),
      ActivityPage(tripService: widget.tripService),
    ];

    return Scaffold(
      extendBody: _selectedIndex == 2,
      body: SafeArea(
        top: _selectedIndex != 2,
        bottom: _selectedIndex != 2,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Material(
          color: BeaconColors.ink,
          elevation: 8,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            indicatorColor: Colors.transparent,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.near_me_outlined),
                selectedIcon: _SelectedNavIcon(icon: Icons.near_me),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: _SelectedNavIcon(icon: Icons.insights),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: _SelectedNavIcon(icon: Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.family_restroom_outlined),
                selectedIcon: _SelectedNavIcon(icon: Icons.family_restroom),
                label: 'Family',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: _SelectedNavIcon(icon: Icons.route),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedNavIcon extends StatelessWidget {
  const _SelectedNavIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      key: const ValueKey('selected-nav-icon'),
      size: 22,
      color: BeaconColors.lime,
    );
  }
}
