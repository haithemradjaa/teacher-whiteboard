import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/dependency_injection_service.dart';
import 'services/logging_service.dart';
import 'services/analytics_service.dart';
import 'services/performance_service.dart';
import 'services/connectivity_service.dart';

enum AppEnvironment {
  development,
  staging,
  production
}

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // Environment configuration
  AppEnvironment _environment = AppEnvironment.development;
  bool _debugMode = kDebugMode;

  // Service dependencies
  final DependencyInjectionService _dependencyService = DependencyInjectionService();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final PerformanceService _performanceService = PerformanceService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Getters
  AppEnvironment get environment => _environment;
  bool get isDebugMode => _debugMode;

  // Configure app environment
  void setEnvironment(AppEnvironment env, {bool? debugMode}) {
    _environment = env;
    _debugMode = debugMode ?? kDebugMode;

    // Configure environment-specific settings
    switch (env) {
      case AppEnvironment.development:
        _configureDevEnvironment();
        break;
      case AppEnvironment.staging:
        _configureStagingEnvironment();
        break;
      case AppEnvironment.production:
        _configureProductionEnvironment();
        break;
    }
  }

  void _configureDevEnvironment() {
    _loggingService.setLogLevel(LogLevel.debug);
    _analyticsService.setEnabled(false);
  }

  void _configureStagingEnvironment() {
    _loggingService.setLogLevel(LogLevel.info);
    _analyticsService.setEnabled(true);
  }

  void _configureProductionEnvironment() {
    _loggingService.setLogLevel(LogLevel.error);
    _analyticsService.setEnabled(true);
  }

  // Global error handling
  void setupErrorHandling() {
    // Flutter framework error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _loggingService.error(
        'Flutter Framework Error',
        error: details.exception,
        stackTrace: details.stack,
      );
      _analyticsService.recordError(details.exception, details.stack);
    };

    // Dart error handling
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _loggingService.error(
        'Dart Platform Error',
        error: error,
        stackTrace: stackTrace,
      );
      _analyticsService.recordError(error, stackTrace);
      return true;
    };
  }

  // Initialize app services
  Future<void> initializeApp() async {
    try {
      // Setup error handling
      setupErrorHandling();

      // Initialize connectivity monitoring
      await _connectivityService.init();

      // Initialize all services
      await _dependencyService.initializeAllServices();

      _loggingService.info('App initialization complete');
      _analyticsService.logEvent(
        name: 'app_initialized',
        parameters: {
          'environment': _environment.toString(),
          'debug_mode': _debugMode,
        },
        category: AnalyticsEventCategory.systemInteraction,
      );
    } catch (e) {
      _loggingService.error('App initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  // Cleanup and dispose resources
  void disposeApp() {
    _dependencyService.disposeAllServices();
    _loggingService.info('App resources disposed');
  }
}