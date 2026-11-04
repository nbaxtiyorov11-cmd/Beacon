import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
    this.photoUrl,
    this.provider = 'password',
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;
  final String? photoUrl;
  final String provider;
}

abstract interface class AuthService {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<void> signIn(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> createAccount(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> updateDisplayName(String displayName);
  Future<void> sendEmailVerification();
  Future<AuthUser?> reloadCurrentUser();
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? firebaseAuth])
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = GoogleSignIn(
        serverClientId:
            '885563935697-lqeae3u5u1rbq8aq1frt4folcs0l1p0t.apps.googleusercontent.com',
      );

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.userChanges().map(_mapUser);

  @override
  Future<void> signIn(String email, String password) => _perform(
    () => _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw const AuthFailure(
          'Google sign-in is not fully configured for Firebase. Check your Google Sign-In setup.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    } on PlatformException catch (error) {
      throw AuthFailure(
        error.message ?? 'Google sign-in could not be completed.',
      );
    } on AuthFailure {
      rethrow;
    } on Exception {
      throw const AuthFailure('Google sign-in could not be completed.');
    }
  }

  @override
  Future<void> createAccount(String email, String password) => _perform(
    () => _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  @override
  Future<void> sendPasswordReset(String email) => _perform(
    () => _firebaseAuth.sendPasswordResetEmail(email: email.trim()),
  );

  @override
  Future<void> updateDisplayName(String displayName) {
    final user = _requireUser();
    return _perform(() => user.updateDisplayName(displayName.trim()));
  }

  @override
  Future<void> sendEmailVerification() {
    final user = _requireUser();
    return _perform(user.sendEmailVerification);
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    final user = _requireUser();
    await _perform(user.reload);
    return currentUser;
  }

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  Future<void> _perform(Future<Object?> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageFor(error));
    }
  }

  String _messageFor(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'The email or password is incorrect.',
      'email-already-in-use' => 'An account already uses this email.',
      'weak-password' => 'Choose a stronger password.',
      'operation-not-allowed' =>
        'Email and password sign-in is not enabled for this Firebase project.',
      'requires-recent-login' =>
        'For security, sign out and sign in again before trying this action.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Check your internet connection and try again.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }

  User _requireUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw const AuthFailure('You are not signed in.');
    return user;
  }

  static AuthUser? _mapUser(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          emailVerified: user.emailVerified,
          photoUrl: user.photoURL,
          provider: user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'password',
        );
}