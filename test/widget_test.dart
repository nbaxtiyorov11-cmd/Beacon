// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:beacon/auth/auth_service.dart';
import 'package:beacon/main.dart';
import 'package:beacon/pages/activity_page.dart';
import 'package:beacon/pages/chats_page.dart';
import 'package:beacon/pages/emergency_page.dart';
import 'package:beacon/pages/family_page.dart';
import 'package:beacon/pages/home_page.dart';
import 'package:beacon/pages/insights_page.dart';
import 'package:beacon/pages/map_page.dart';
import 'package:beacon/pages/notifications_page.dart';
import 'package:beacon/services/firestore_service.dart';
import 'package:beacon/services/location_service.dart';
import 'package:beacon/services/trip_service.dart';
import 'package:beacon/theme/beacon_theme.dart';

Position _gpsPosition(
  double latitude,
  double longitude,
  DateTime timestamp, {
  double accuracy = 5,
}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('safe place radius includes nearby GPS fixes and names trips', () {
    const place = SafePlace(
      id: 'home',
      name: 'Home',
      latitude: 41.3,
      longitude: 69.2,
      radiusMeters: 150,
    );
    final timestamp = DateTime.utc(2026, 10, 20, 10);

    expect(
      place.contains(_gpsPosition(41.301, 69.2, timestamp)),
      isTrue,
    );
    expect(
      place.contains(_gpsPosition(41.303, 69.2, timestamp)),
      isFalse,
    );

    final trip = TripService().recordTripFromPositions(
      [_gpsPosition(41.301, 69.2, timestamp)],
      name: place.name,
    );
    expect(trip?.title, 'Home');
  });

  test('safe-place visit history splits duration across date boundaries', () {
    final visit = SafePlaceVisit(
      id: 'visit',
      placeId: 'home',
      placeName: 'Home',
      startedAt: DateTime.utc(2026, 11, 4, 23, 30),
      endedAt: DateTime.utc(2026, 11, 5, 0, 30),
      durationSeconds: 3600,
    );

    expect(
      visit.secondsOverlapping(
        DateTime.utc(2026, 11, 4),
        DateTime.utc(2026, 11, 5),
      ),
      1800,
    );
    expect(
      visit.secondsOverlapping(
        DateTime.utc(2026, 11, 5),
        DateTime.utc(2026, 11, 6),
      ),
      1800,
    );
  });

  test('heatmap uses only trip points in the selected time window', () {
    final now = DateTime(2026, 10, 17);
    final points = MapPage.heatmapPoints(
      [
        TripEntry(
          id: 'recent',
          startedAt: now.subtract(const Duration(days: 2)),
          endedAt: now.subtract(const Duration(days: 2)),
          points: const [
            TripLocation(latitude: 41.3, longitude: 69.2),
            TripLocation(latitude: 41.31, longitude: 69.21),
          ],
          distanceMeters: 1200,
          averageSpeedKmh: 3,
        ),
        TripEntry(
          id: 'older',
          startedAt: now.subtract(const Duration(days: 20)),
          endedAt: now.subtract(const Duration(days: 20)),
          points: const [TripLocation(latitude: 40, longitude: 68)],
          distanceMeters: 800,
          averageSpeedKmh: 2,
        ),
      ],
      now: now,
      window: HeatmapWindow.week,
    );

    expect(points, hasLength(2));
    expect(
        points.any((point) => point.point == const LatLng(41.3, 69.2)), isTrue);
  });

  test('tracking trace filters GPS noise and keeps newest path points', () {
    const start = LatLng(41.3, 69.2);
    final points = MapPage.appendTrackingPoint([], start);
    final tooClose = MapPage.appendTrackingPoint(
      points,
      const LatLng(41.300001, 69.200001),
    );
    final moved = MapPage.appendTrackingPoint(
      tooClose,
      const LatLng(41.301, 69.201),
    );

    expect(tooClose, hasLength(1));
    expect(moved, hasLength(2));
    expect(moved.last, const LatLng(41.301, 69.201));
  });

  test('phone-off GPS gaps break traces and are excluded from distance', () {
    final startTime = DateTime.utc(2026, 10, 18, 10);
    final positions = [
      _gpsPosition(41.3, 69.2, startTime),
      _gpsPosition(41.3001, 69.2001, startTime.add(const Duration(seconds: 5))),
      _gpsPosition(41.5, 69.5, startTime.add(const Duration(minutes: 5))),
    ];
    final trip = TripService().recordTripFromPositions(positions)!;
    final expectedMeasuredDistance = Geolocator.distanceBetween(
      positions[0].latitude,
      positions[0].longitude,
      positions[1].latitude,
      positions[1].longitude,
    );
    final traceSegments = MapPage.buildTrackingSegments(positions);

    expect(trip.distanceMeters, closeTo(expectedMeasuredDistance, 0.1));
    expect(trip.movingSeconds, 5);
    expect(trip.points.map((point) => point.segmentStart), [true, false, true]);
    expect(traceSegments.map((segment) => segment.length), [2, 1]);
  });

  test('paused trip segments do not add paused time or distance', () {
    final startTime = DateTime.utc(2026, 10, 18, 10);
    final positions = [
      _gpsPosition(41.3, 69.2, startTime),
      _gpsPosition(41.3001, 69.2001, startTime.add(const Duration(seconds: 5))),
      _gpsPosition(41.5, 69.5, startTime.add(const Duration(seconds: 7))),
    ];
    final trip = TripService().recordTripFromPositions(
      positions,
      segmentStartIndices: const {2},
    )!;
    final distanceBeforePause = Geolocator.distanceBetween(
      positions[0].latitude,
      positions[0].longitude,
      positions[1].latitude,
      positions[1].longitude,
    );

    expect(trip.distanceMeters, closeTo(distanceBeforePause, 0.1));
    expect(trip.movingSeconds, 5);
    expect(trip.points.map((point) => point.segmentStart), [true, false, true]);
  });

  test('trip recording rejects inaccurate jitter and impossible GPS jumps', () {
    final startTime = DateTime.utc(2026, 10, 18, 10);
    final positions = [
      _gpsPosition(41.3, 69.2, startTime),
      _gpsPosition(
        41.300002,
        69.2,
        startTime.add(const Duration(seconds: 2)),
        accuracy: 25,
      ),
      _gpsPosition(
        41.5,
        69.5,
        startTime.add(const Duration(seconds: 4)),
      ),
      _gpsPosition(
        41.3002,
        69.2,
        startTime.add(const Duration(seconds: 10)),
      ),
    ];

    final trip = TripService().recordTripFromPositions(positions)!;
    final expectedDistance = Geolocator.distanceBetween(
      positions.first.latitude,
      positions.first.longitude,
      positions.last.latitude,
      positions.last.longitude,
    );

    expect(trip.points, hasLength(2));
    expect(trip.distanceMeters, closeTo(expectedDistance, 0.1));
    expect(trip.movingSeconds, 10);
  });

  test('profile refresh payload leaves saved settings untouched', () {
    final payload = FirestoreService.userProfileUpdateData(
      const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );

    expect(payload, isNot(contains('settings')));
  });

  testWidgets('tracking toggle can be driven by a real location service', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    final locationService = _FakeLocationService();

    await tester.pumpWidget(
      BeaconApp(
        authService: authService,
        locationService: locationService,
        trackingNotificationsEnabled: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRACKING PAUSED'), findsOneWidget);

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    expect(find.text('TRACKING LIVE'), findsOneWidget);
    expect(locationService.startCalls, 1);
    await authService.dispose();
  });

  testWidgets('pausing and continuing preserves the active trip', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    final locationService = _FakeLocationService();

    await tester.pumpWidget(BeaconApp(
      authService: authService,
      locationService: locationService,
      trackingNotificationsEnabled: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('tracking-session-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('end-trip-action')), findsOneWidget);
    await tester.tap(find.text('Pause trip'));
    await tester.pumpAndSettle();

    expect(find.text('TRACKING PAUSED'), findsOneWidget);
    expect(find.text('End trip'), findsOneWidget);
    expect(find.text('1.2 km'), findsWidgets);
    expect(find.textContaining('3 min active · Trip paused'), findsOneWidget);

    await tester.tap(find.text('Continue trip'));
    await tester.pumpAndSettle();

    expect(find.text('TRACKING LIVE'), findsOneWidget);
    expect(locationService.startCalls, 1);
    expect(locationService.resumeCalls, 1);
    expect(locationService.hasActiveTrip, isTrue);
    await authService.dispose();
  });

  testWidgets('stopping tracking updates the UI before settings are saved', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    final firestoreService = _DelayedSettingsFirestoreService();
    await tester.pumpWidget(BeaconApp(
      authService: authService,
      locationService: _FakeLocationService(),
      firestoreService: firestoreService,
      trackingNotificationsEnabled: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();
    expect(find.text('TRACKING LIVE'), findsOneWidget);

    await tester.tap(find.text('Pause trip'));
    await tester.pump();
    expect(find.text('TRACKING PAUSED'), findsOneWidget);
    expect(firestoreService.settingsWriteCalls, greaterThanOrEqualTo(2));

    firestoreService.finishSaves();
    await tester.pumpAndSettle();
    await authService.dispose();
  });

  testWidgets('login persists across restart and logout clears session', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(BeaconApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'secret123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining(', there.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(BeaconApp(authService: authService));
    await tester.pumpAndSettle();
    expect(find.textContaining(', there.'), findsOneWidget);

    await tester.tap(find.byTooltip('Your profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out').last);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await authService.dispose();
  });

  testWidgets('login screen includes Google sign-in and polished fields', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(BeaconApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    await authService.dispose();
  });

  testWidgets('tracking toggle works after sign-in',
      (WidgetTester tester) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    final locationService = _FakeLocationService();
    await tester.pumpWidget(
      BeaconApp(
        authService: authService,
        locationService: locationService,
        trackingNotificationsEnabled: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRACKING PAUSED'), findsOneWidget);
    await tester.tap(find.text('Start tracking'));
    await tester.pump();
    expect(find.text('TRACKING LIVE'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Movement history'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(find.text('Your insights'), findsOneWidget);
    await authService.dispose();
  });

  testWidgets('main navigation order and header chats route are correct', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    await tester.pumpWidget(BeaconApp(
      authService: authService,
      firestoreService: _FakeChatFirestoreService(),
    ));
    await tester.pumpAndSettle();

    final destinations = tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .destinations
        .map((destination) => (destination as NavigationDestination).label)
        .toList();
    expect(
      destinations,
      ['Today', 'Insights', 'Map', 'Family', 'History'],
    );
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.indicatorColor, Colors.transparent);
    final selectedIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('selected-nav-icon')),
    );
    expect(selectedIcon.color, BeaconColors.lime);
    await tester.tap(find.byTooltip('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
      isTrue,
    );
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
      isFalse,
    );

    expect(find.text('Family circle'), findsOneWidget);
    expect(find.text('Chats'), findsNothing);
    expect(find.text('Family chats'), findsNothing);
    await authService.dispose();
  });

  testWidgets('new users can create an account', (WidgetTester tester) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(BeaconApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('New to Beacon? Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to Beacon? Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'new-user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'secure123',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.textContaining(', there.'), findsOneWidget);
    await authService.dispose();
  });

  testWidgets('profile opens from home and can update display name', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      initialUser: const AuthUser(uid: 'alex-id', email: 'alex@example.com'),
    );
    await tester.pumpWidget(BeaconApp(authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('alex@example.com'), findsWidgets);

    await tester.ensureVisible(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alex Beacon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Alex Beacon'), findsWidgets);
    await authService.dispose();
  });

  testWidgets('saved trips show a trip detail summary in history', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final tripService = TripService();
    tripService.addTrip(
      TripEntry(
        id: 'trip-1',
        startedAt: now.subtract(const Duration(hours: 1)),
        endedAt: now,
        points: const [
          TripLocation(latitude: 52.52, longitude: 13.405),
          TripLocation(latitude: 52.53, longitude: 13.41),
          TripLocation(latitude: 52.54, longitude: 13.42),
        ],
        distanceMeters: 1600,
        averageSpeedKmh: 18.5,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActivityPage(tripService: tripService)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip detail'), findsOneWidget);
    expect(find.text('1.6 km'), findsWidgets);
  });

  testWidgets('history day chips filter trips to the selected date', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripService = TripService()
      ..replaceTrips([
        TripEntry(
          id: 'today',
          startedAt: today.add(const Duration(hours: 8)),
          endedAt: today.add(const Duration(hours: 9)),
          points: const [TripLocation(latitude: 1, longitude: 1)],
          distanceMeters: 500,
          averageSpeedKmh: 3,
        ),
        TripEntry(
          id: 'yesterday',
          startedAt: today
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 8)),
          endedAt: today
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 9)),
          points: const [TripLocation(latitude: 2, longitude: 2)],
          distanceMeters: 2500,
          averageSpeedKmh: 5,
        ),
      ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ActivityPage(tripService: tripService)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0.5 km'), findsWidgets);
    await tester.tap(find.text('1d ago'));
    await tester.pumpAndSettle();

    expect(find.text('2.5 km'), findsWidgets);
    expect(find.text('0.5 km'), findsNothing);
  });

  testWidgets('insights use recorded trips instead of sample analytics', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final tripService = TripService()
      ..addTrip(TripEntry(
        id: 'recent-trip',
        startedAt: now.subtract(const Duration(days: 2, hours: 1)),
        endedAt: now.subtract(const Duration(days: 2)),
        points: const [TripLocation(latitude: 1, longitude: 1)],
        distanceMeters: 2500,
        averageSpeedKmh: 5,
      ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InsightsPage(tripService: tripService)),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('No previous period data to compare yet'), findsOneWidget);
    expect(find.text('12% more than the previous period'), findsNothing);
    expect(find.textContaining('You covered 2.5 km across 1 trip'),
        findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('MONTHLY DISTANCE'), findsOneWidget);
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    expect(find.text('YEARLY DISTANCE'), findsOneWidget);
  });

  testWidgets('Today metrics are calculated from real trip data', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final trips = [
      TripEntry(
        id: 'today-trip',
        startedAt: today.add(const Duration(hours: 8)),
        endedAt: today.add(const Duration(hours: 8, minutes: 30)),
        points: const [TripLocation(latitude: 1, longitude: 1)],
        distanceMeters: 1200,
        averageSpeedKmh: 2.4,
      ),
      TripEntry(
        id: 'yesterday-trip',
        startedAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 8)),
        endedAt: today
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 9)),
        points: const [TripLocation(latitude: 2, longitude: 2)],
        distanceMeters: 3000,
        averageSpeedKmh: 3,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomePage(
          trackingEnabled: false,
          onTrackingChanged: (_) {},
          userName: 'Alex Morgan',
          onOpenChats: () {},
          onOpenProfile: () {},
          onOpenNotifications: () {},
          onOpenEmergency: () {},
          trips: trips,
          liveTrackingDistanceMeters: 0,
          trackingStartedAt: null,
          pendingNotificationCount: 3,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 17 ? 'afternoon' : 'evening'}, Alex.'),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pending-notification-count')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.text('1.2 km'), findsWidgets);
    expect(find.text('30 min'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Today’s movement'));
    await tester.pumpAndSettle();
    expect(find.text('1 trip'), findsOneWidget);
    expect(find.text('4.2 km'), findsOneWidget);
  });

  testWidgets('member lookup opens profile and starts a chat', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeChatFirestoreService();
    await tester.pumpWidget(MaterialApp(
      home: ChatsPage(
        currentUser: const AuthUser(
          uid: 'user-1',
          email: 'alex@example.com',
          displayName: 'Alex',
        ),
        firestoreService: firestoreService,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Find a Beacon member'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'maya@example.com');
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();

    expect(find.text('Maya R.'), findsOneWidget);
    expect(find.text('ACTIVITY AT A GLANCE'), findsOneWidget);
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();

    expect(find.text('Say hello to Maya R.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Hello 🙂');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(firestoreService.openedProfile?.uid, 'member-2');
    expect(firestoreService.sentMessages.single, 'Hello 🙂');
  });

  testWidgets('family page shows trusted contacts and sharing controls', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeFamilyFirestoreService(
      contacts: const [
        FamilyContact(
          id: 'member-1',
          name: 'Maya R.',
          email: 'maya@example.com',
          relation: 'Connected',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyPage(
            userId: 'user-1',
            currentUser:
                const AuthUser(uid: 'user-1', email: 'owner@example.com'),
            firestoreService: firestoreService,
            onFamilySharingChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maya R.'), findsOneWidget);
    expect(find.text('Share my location'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('safe-place picker opens while GPS lookup is pending', (
    WidgetTester tester,
  ) async {
    final locationService = _SlowLocationService();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamilyPage(
          userId: 'user-1',
          currentUser:
              const AuthUser(uid: 'user-1', email: 'owner@example.com'),
          firestoreService: _FakeFamilyFirestoreService(),
          locationService: locationService,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add a safe place'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a safe place'));
    await tester.pumpAndSettle();

    expect(find.text('Add safe place'), findsOneWidget);
    final radiusSlider = tester.widget<Slider>(find.byType(Slider));
    expect(radiusSlider.min, 20);
    expect(radiusSlider.divisions, 48);
    final circle =
        tester.widget<CircleLayer>(find.byType(CircleLayer)).circles.single;
    expect(circle.useRadiusInMeter, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('family sharing toggle awaits its update callback', (
    WidgetTester tester,
  ) async {
    var sharingRequested = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamilyPage(
          userId: 'user-1',
          currentUser:
              const AuthUser(uid: 'user-1', email: 'owner@example.com'),
          firestoreService: _FakeFamilyFirestoreService(),
          onFamilySharingChanged: (enabled) async {
            sharingRequested = enabled;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(sharingRequested, isTrue);
    expect(find.text('Sharing is on'), findsOneWidget);
  });

  testWidgets('active family SOS appears in notifications', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeFamilyFirestoreService(
      contacts: [
        FamilyContact(
          id: 'member-1',
          name: 'Maya R.',
          email: 'maya@example.com',
          emergencyActive: true,
          emergencyLatitude: 41.3,
          emergencyLongitude: 69.2,
          emergencyUpdatedAt: DateTime.now(),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: NotificationsPage(
        userId: 'user-1',
        currentUser: const AuthUser(uid: 'user-1', email: 'owner@example.com'),
        firestoreService: firestoreService,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Maya R. needs help'), findsOneWidget);
    expect(find.text('41.30000, 69.20000'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Maya R. needs help'), findsNothing);
    expect(find.text('You’re all caught up'), findsOneWidget);

    await tester.tap(find.text('Emergency'));
    await tester.pumpAndSettle();
    expect(find.text('Maya R. needs help'), findsOneWidget);
  });

  testWidgets('holding SOS sends an alert and exposes its cancel action', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeEmergencyFirestoreService();
    await tester.pumpWidget(MaterialApp(
      home: EmergencyPage(
        user: const AuthUser(uid: 'user-1', email: 'owner@example.com'),
        locationService: _FakeLocationService(),
        firestoreService: firestoreService,
      ),
    ));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('SOS')));
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(firestoreService.alertActive, isTrue);
    expect(find.text('I am safe · cancel alert'), findsOneWidget);
    await tester.tap(find.text('I am safe · cancel alert'));
    await tester.pumpAndSettle();
    expect(firestoreService.alertActive, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping a family friend opens their profile', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeFamilyFirestoreService(
      contacts: const [
        FamilyContact(
          id: 'member-1',
          name: 'Maya R.',
          email: 'maya@example.com',
          relation: 'Connected',
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FamilyPage(
          userId: 'user-1',
          currentUser:
              const AuthUser(uid: 'user-1', email: 'owner@example.com'),
          firestoreService: firestoreService,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maya R.'));
    await tester.pumpAndSettle();

    expect(find.text('Member profile'), findsOneWidget);
    expect(find.text('ACTIVITY AT A GLANCE'), findsOneWidget);
  });

  testWidgets('family invite only sends requests to existing accounts', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeFamilyFirestoreService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyPage(
            userId: 'user-1',
            currentUser:
                const AuthUser(uid: 'user-1', email: 'owner@example.com'),
            firestoreService: firestoreService,
            onFamilySharingChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'missing@example.com');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(find.text('No Beacon account was found for that email.'),
        findsOneWidget);
    expect(firestoreService.invitationTargets, isEmpty);
    expect(find.text('Accepted connections will appear here.'), findsOneWidget);

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'maya@example.com');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();

    expect(firestoreService.invitationTargets, ['maya@example.com']);
    expect(find.text('Accepted connections will appear here.'), findsOneWidget);
  });

  testWidgets('connected family members can be removed from the circle', (
    WidgetTester tester,
  ) async {
    final firestoreService = _FakeFamilyFirestoreService(
      contacts: const [
        FamilyContact(
          id: 'member-1',
          name: 'Maya R.',
          email: 'maya@example.com',
          relation: 'Connected',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyPage(
            userId: 'user-1',
            currentUser:
                const AuthUser(uid: 'user-1', email: 'owner@example.com'),
            firestoreService: firestoreService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(firestoreService.removedMemberIds, ['member-1']);
  });

  testWidgets(
      'incoming family request stays in notifications instead of the family page',
      (
    WidgetTester tester,
  ) async {
    const invitation = FamilyInvitation(
      id: 'request-1',
      fromUid: 'member-1',
      fromName: 'Maya R.',
      fromEmail: 'maya@example.com',
      toUid: 'user-1',
      toName: 'Alex',
      toEmail: 'owner@example.com',
    );
    final firestoreService = _FakeFamilyFirestoreService(
      invitations: [invitation],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyPage(
            userId: 'user-1',
            currentUser:
                const AuthUser(uid: 'user-1', email: 'owner@example.com'),
            firestoreService: firestoreService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family requests'), findsNothing);
    expect(find.text('Accepted connections will appear here.'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsPage(
          userId: 'user-1',
          currentUser:
              const AuthUser(uid: 'user-1', email: 'owner@example.com'),
          firestoreService: firestoreService,
          initialInvitations: const [invitation],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family requests'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(firestoreService.acceptedInvitationIds, ['request-1']);
  });
}

class _FakeFamilyFirestoreService extends FirestoreService {
  _FakeFamilyFirestoreService({
    this.contacts = const [],
    this.invitations = const [],
  });

  final List<FamilyContact> contacts;
  final List<FamilyInvitation> invitations;
  final List<String> invitationTargets = [];
  final List<String> acceptedInvitationIds = [];
  final List<String> removedMemberIds = [];

  @override
  Stream<List<FamilyContact>> watchFamilyContacts(String uid) =>
      Stream.value(contacts);

  @override
  Stream<List<FamilyInvitation>> watchIncomingFamilyInvitations(String uid) =>
      Stream.value(invitations);

  @override
  Future<FamilyInviteResult> sendFamilyInvitation({
    required AuthUser sender,
    required String targetEmail,
  }) async {
    if (targetEmail != 'maya@example.com') {
      return FamilyInviteResult.accountNotFound;
    }
    invitationTargets.add(targetEmail);
    return FamilyInviteResult.sent;
  }

  @override
  Future<void> respondToFamilyInvitation({
    required String userId,
    required FamilyInvitation invitation,
    required bool accept,
  }) async {
    if (accept) acceptedInvitationIds.add(invitation.id);
  }

  @override
  Future<void> removeFamilyConnection({
    required String userId,
    required String targetUid,
  }) async {
    removedMemberIds.add(targetUid);
  }
}

class _FakeEmergencyFirestoreService extends FirestoreService {
  bool alertActive = false;

  @override
  Future<Map<String, String>> fetchEmergencyContact(String userId) async =>
      const {};

  @override
  Future<int> updateEmergencyAlert({
    required String userId,
    required double? latitude,
    required double? longitude,
  }) async {
    alertActive = true;
    return 1;
  }

  @override
  Future<void> clearEmergencyAlert(String userId) async {
    alertActive = false;
  }
}

class _FakeChatFirestoreService extends FirestoreService {
  final List<String> sentMessages = [];
  PublicUserProfile? openedProfile;

  @override
  Stream<List<ChatConversation>> watchChatConversations(String uid) =>
      Stream.value(const []);

  @override
  Future<PublicUserProfile?> findPublicProfileByEmail(String email) async {
    if (email.trim().toLowerCase() != 'maya@example.com') return null;
    return const PublicUserProfile(
      uid: 'member-2',
      email: 'maya@example.com',
      displayName: 'Maya R.',
    );
  }

  @override
  Future<PublicActivityStats> fetchPublicActivityStats(String uid) async =>
      const PublicActivityStats(
          tripCount: 12, distanceMeters: 18000, movingMinutes: 450);

  @override
  Future<String> openOrCreateChat({
    required AuthUser currentUser,
    required PublicUserProfile otherUser,
  }) async {
    openedProfile = otherUser;
    return 'chat-id';
  }

  @override
  Stream<List<ChatMessage>> watchChatMessages(String chatId) =>
      Stream.value(const []);

  @override
  Stream<ChatConversation?> watchChatConversation(String chatId) =>
      Stream.value(null);

  @override
  Future<void> sendChatMessage({
    required String chatId,
    required String senderUid,
    required String text,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderUid,
  }) async {
    sentMessages.add(text);
  }

  @override
  Future<void> markChatRead({
    required String chatId,
    required String readerUid,
  }) async {}
}

class _FakeLocationService extends LocationService {
  _FakeLocationService();

  int startCalls = 0;
  int resumeCalls = 0;
  bool _hasActiveTrip = false;
  bool _trackingEnabled = false;

  @override
  bool get hasActiveTrip => _hasActiveTrip;

  @override
  bool get trackingEnabled => _trackingEnabled;

  @override
  Future<bool> requestTrackingPermission() async => true;

  @override
  double get trackedDistanceMeters => _hasActiveTrip ? 1234 : 0;

  @override
  Duration get trackingDuration =>
      _hasActiveTrip ? const Duration(minutes: 3) : Duration.zero;

  @override
  Future<Position?> getCurrentPosition() async => null;

  @override
  Future<bool> startTracking() async {
    startCalls += 1;
    _hasActiveTrip = true;
    _trackingEnabled = true;
    return true;
  }

  @override
  Future<bool> resumeTracking() async {
    resumeCalls += 1;
    _trackingEnabled = true;
    return true;
  }

  @override
  Future<void> pauseTracking() async {
    _trackingEnabled = false;
  }

  @override
  Future<void> stopTracking() async {
    _trackingEnabled = false;
    _hasActiveTrip = false;
  }
}

class _SlowLocationService extends LocationService {
  final Completer<Position?> _position = Completer<Position?>();

  @override
  Future<Position?> getCurrentPosition() => _position.future;
}

class _DelayedSettingsFirestoreService extends FirestoreService {
  final Completer<void> _saveCompleter = Completer<void>();
  int settingsWriteCalls = 0;

  @override
  Future<UserSettings> fetchUserSettings(String uid) async =>
      const UserSettings();

  @override
  Stream<List<TripEntry>> watchTrips(String uid) => Stream.value(const []);

  @override
  Future<void> saveUserSettings(String uid, UserSettings settings) {
    settingsWriteCalls++;
    return _saveCompleter.future;
  }

  void finishSaves() {
    if (!_saveCompleter.isCompleted) _saveCompleter.complete();
  }
}

class _FakeAuthService implements AuthService {
  _FakeAuthService({AuthUser? initialUser}) : _user = initialUser;

  AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    _setUser(email);
  }

  @override
  Future<void> signInWithGoogle() async {
    _setUser('google-user@example.com');
  }

  @override
  Future<void> createAccount(String email, String password) async {
    _setUser(email);
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updateDisplayName(String displayName) async {
    _user = AuthUser(
      uid: _user!.uid,
      email: _user!.email,
      displayName: displayName,
      emailVerified: _user!.emailVerified,
    );
    _controller.add(_user);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser?> reloadCurrentUser() async => _user;

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }

  void _setUser(String email) {
    _user = AuthUser(uid: 'test-user', email: email);
    _controller.add(_user);
  }

  Future<void> dispose() => _controller.close();
}
