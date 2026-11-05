import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/beacon_shell.dart';
import 'auth/login_page.dart';
import 'auth/auth_service.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'services/trip_service.dart';
import 'theme/beacon_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(BeaconApp());
}

class BeaconApp extends StatefulWidget {
  BeaconApp({
    super.key,
    AuthService? authService,
    LocationService? locationService,
    TripService? tripService,
    FirestoreService? firestoreService,
  }) : authService = authService ?? FirebaseAuthService(),
       locationService = locationService ?? LocationService(),
       tripService = tripService ?? TripService(),
       firestoreService = firestoreService ?? FirestoreService();

  final AuthService authService;
  final LocationService locationService;
  final TripService tripService;
  final FirestoreService firestoreService;

  @override
  State<BeaconApp> createState() => _BeaconAppState();
}

class _BeaconAppState extends State<BeaconApp> {
  BeaconThemePreset _themePreset = BeaconThemePreset.active;

  void _updateThemePreset(BeaconThemePreset preset) {
    if (!mounted) return;
    setState(() => _themePreset = preset);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = BeaconTheme.forPreset(_themePreset);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Beacon',
      theme: appTheme,
      home: _SessionGate(
        authService: widget.authService,
        locationService: widget.locationService,
        tripService: widget.tripService,
        firestoreService: widget.firestoreService,
        themePreset: _themePreset,
        onThemeChanged: _updateThemePreset,
      ),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate({
    required this.authService,
    required this.locationService,
    required this.tripService,
    required this.firestoreService,
    required this.themePreset,
    required this.onThemeChanged,
  });

  final AuthService authService;
  final LocationService locationService;
  final TripService tripService;
  final FirestoreService firestoreService;
  final BeaconThemePreset themePreset;
  final ValueChanged<BeaconThemePreset> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not connect to Firebase.')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginPage(
            onSignIn: authService.signIn,
            onGoogleSignIn: authService.signInWithGoogle,
            onCreateAccount: authService.createAccount,
            onPasswordReset: authService.sendPasswordReset,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          firestoreService.saveUserProfile(user);
        });

        return BeaconShell(
          key: ValueKey(user.uid),
          user: user,
          authService: authService,
          locationService: locationService,
          tripService: tripService,
          firestoreService: firestoreService,
          themePreset: themePreset,
          onThemeChanged: onThemeChanged,
        );
      },
    );
  }
}