import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'logging_service.dart';
import 'analytics_service.dart';

enum AuthenticationStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
  error
}

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool emailVerified;

  UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.emailVerified = false,
  });

  factory UserProfile.fromFirebaseUser(User user) => UserProfile(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoURL: user.photoURL,
    emailVerified: user.emailVerified,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoURL': photoURL,
    'emailVerified': emailVerified,
  };
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  final _authStatusController = StreamController<AuthenticationStatus>.broadcast();
  final _userProfileController = StreamController<UserProfile?>.broadcast();

  Stream<AuthenticationStatus> get authStatusStream => _authStatusController.stream;
  Stream<UserProfile?> get userProfileStream => _userProfileController.stream;

  UserProfile? get currentUser => _currentUserProfile;
  UserProfile? _currentUserProfile;

  Future<void> init() async {
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUserProfile = UserProfile.fromFirebaseUser(user);
        _userProfileController.add(_currentUserProfile);
        _authStatusController.add(AuthenticationStatus.authenticated);
        
        _analyticsService.logEvent(
          name: 'user_authenticated',
          parameters: {'method': 'firebase'},
          category: AnalyticsEventCategory.authentication,
        );
      } else {
        _currentUserProfile = null;
        _userProfileController.add(null);
        _authStatusController.add(AuthenticationStatus.unauthenticated);
      }
    });
  }

  Future<UserProfile?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _authStatusController.add(AuthenticationStatus.authenticating);
      
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _loggingService.info('User signed in: ${userCredential.user?.email}');
      return _currentUserProfile;
    } on FirebaseAuthException catch (e) {
      _loggingService.error('Email sign-in failed', error: e);
      _authStatusController.add(AuthenticationStatus.error);
      _analyticsService.recordError(e, StackTrace.current);
      return null;
    }
  }

  Future<UserProfile?> signInWithGoogle() async {
    try {
      _authStatusController.add(AuthenticationStatus.authenticating);

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _authStatusController.add(AuthenticationStatus.unauthenticated);
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      _loggingService.info('Google sign-in successful: ${userCredential.user?.email}');
      return _currentUserProfile;
    } catch (e) {
      _loggingService.error('Google sign-in failed', error: e);
      _authStatusController.add(AuthenticationStatus.error);
      _analyticsService.recordError(e, StackTrace.current);
      return null;
    }
  }

  Future<UserProfile?> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _authStatusController.add(AuthenticationStatus.authenticating);
      
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.sendEmailVerification();

      _loggingService.info('User registered: ${userCredential.user?.email}');
      return _currentUserProfile;
    } on FirebaseAuthException catch (e) {
      _loggingService.error('User registration failed', error: e);
      _authStatusController.add(AuthenticationStatus.error);
      _analyticsService.recordError(e, StackTrace.current);
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();

      _loggingService.info('User signed out');
      _authStatusController.add(AuthenticationStatus.unauthenticated);
    } catch (e) {
      _loggingService.error('Sign out failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      _loggingService.info('Password reset email sent');
    } catch (e) {
      _loggingService.error('Password reset failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  void dispose() {
    _authStatusController.close();
    _userProfileController.close();
  }
}