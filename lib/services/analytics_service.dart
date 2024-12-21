import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'logging_service.dart';
import 'auth_service.dart';

enum AnalyticsEventCategory {
  userInteraction,
  navigation,
  authentication,
  fileManagement,
  systemInteraction,
  performance,
  error
}

class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final AnalyticsEventCategory category;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    this.parameters = const {},
    required this.category,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'parameters': parameters,
    'category': category.toString(),
    'timestamp': timestamp.toIso8601String(),
  };
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _firebaseAnalytics = FirebaseAnalytics.instance;
  final LoggingService _loggingService = LoggingService();
  final AuthService _authService = AuthService();

  final _eventController = StreamController<AnalyticsEvent>.broadcast();
  final _performanceController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<AnalyticsEvent> get eventStream => _eventController.stream;
  Stream<Map<String, dynamic>> get performanceStream => _performanceController.stream;

  bool _isEnabled = true;

  Future<void> init() async {
    try {
      // Configure Firebase Analytics
      await _firebaseAnalytics.setAnalyticsCollectionEnabled(!kDebugMode);
      
      // Set default user properties
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await setUserProperties(
          userId: currentUser.uid,
          email: currentUser.email,
          displayName: currentUser.displayName,
        );
      }

      _loggingService.info('Analytics service initialized');
    } catch (e) {
      _loggingService.error('Analytics initialization failed', error: e);
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    _firebaseAnalytics.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> setUserProperties({
    String? userId,
    String? email,
    String? displayName,
  }) async {
    if (!_isEnabled) return;

    try {
      if (userId != null) {
        await _firebaseAnalytics.setUserId(id: userId);
      }

      final properties = <String, String>{};
      if (email != null) properties['email'] = email;
      if (displayName != null) properties['display_name'] = displayName;

      await _firebaseAnalytics.setUserProperties(properties: properties);
    } catch (e) {
      _loggingService.error('Failed to set user properties', error: e);
    }
  }

  void logEvent({
    required String name,
    Map<String, dynamic>? parameters,
    required AnalyticsEventCategory category,
  }) {
    if (!_isEnabled) return;

    try {
      final event = AnalyticsEvent(
        name: name,
        parameters: parameters ?? {},
        category: category,
      );

      // Log to Firebase Analytics
      _firebaseAnalytics.logEvent(
        name: name,
        parameters: parameters,
      );

      // Log to internal stream
      _eventController.add(event);

      // Log to logging service
      _loggingService.info(
        'Analytics Event: $name',
        error: {
          'category': category.toString(),
          'parameters': json.encode(parameters),
        },
      );
    } catch (e) {
      _loggingService.error('Failed to log analytics event', error: e);
    }
  }

  void recordError(dynamic error, StackTrace? stackTrace, {
    bool fatal = false,
    Map<String, dynamic>? extraParameters,
  }) {
    if (!_isEnabled) return;

    try {
      // Log to Firebase Crashlytics
      _firebaseAnalytics.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString(),
          'fatal': fatal,
          ...?extraParameters,
        },
      );

      // Log to logging service
      _loggingService.error(
        'Analytics Error Tracking',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (e) {
      _loggingService.error('Failed to record error', error: e);
    }
  }

  Future<void> startPerformanceTrace(String traceName) async {
    if (!_isEnabled) return;

    try {
      final startTime = DateTime.now();
      
      _performanceController.add({
        'name': traceName,
        'start_time': startTime,
        'status': 'started',
      });

      _loggingService.info('Performance trace started: $traceName');
    } catch (e) {
      _loggingService.error('Failed to start performance trace', error: e);
    }
  }

  Future<void> stopPerformanceTrace(String traceName) async {
    if (!_isEnabled) return;

    try {
      final endTime = DateTime.now();
      
      _performanceController.add({
        'name': traceName,
        'end_time': endTime,
        'status': 'completed',
      });

      _loggingService.info('Performance trace completed: $traceName');
    } catch (e) {
      _loggingService.error('Failed to stop performance trace', error: e);
    }
  }

  void dispose() {
    _eventController.close();
    _performanceController.close();
  }
}