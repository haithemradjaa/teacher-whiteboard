import 'dart:async';

import 'analytics_service.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'connectivity_service.dart';
import 'device_info_service.dart';
import 'feature_flag_service.dart';
import 'localization_service.dart';
import 'logging_service.dart';
import 'notification_service.dart';
import 'performance_service.dart';
import 'recording_service.dart';
import 'storage_service.dart';
import 'tutorial_service.dart';

class ServiceLocator {
  // Singleton instance
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Service registry
  final Map<Type, dynamic> _services = {};
  final Map<Type, Future<void> Function()> _initializers = {};

  // Dependency registration
  void register<T>(T service, {Future<void> Function()? initializer}) {
    _services[T] = service;
    if (initializer != null) {
      _initializers[T] = initializer;
    }
  }

  // Service retrieval
  T get<T>() {
    final service = _services[T];
    if (service == null) {
      throw Exception('Service of type $T not registered');
    }
    return service;
  }

  // Check if service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T);
  }

  // Initialize all registered services
  Future<void> initializeServices() async {
    final initializationTasks = <Future<void>>[];

    for (var entry in _initializers.entries) {
      initializationTasks.add(entry.value());
    }

    await Future.wait(initializationTasks);
  }

  // Dispose all registered services
  void disposeServices() {
    for (var service in _services.values) {
      if (service is CloudSyncService) {
        service.dispose();
      } else if (service is ConnectivityService) {
        service.dispose();
      } else if (service is LocalizationService) {
        service.dispose();
      }
      // Add more dispose methods for other services as needed
    }
    _services.clear();
    _initializers.clear();
  }
}

class DependencyInjection {
  static final ServiceLocator _serviceLocator = ServiceLocator();

  // Initialize all core services
  static Future<void> init() async {
    // Core Services
    _serviceLocator.register<LoggingService>(LoggingService());
    _serviceLocator.register<AnalyticsService>(AnalyticsService());
    _serviceLocator.register<DeviceInfoService>(DeviceInfoService());
    
    // Connectivity and Performance
    _serviceLocator.register<ConnectivityService>(ConnectivityService(), 
      initializer: () => _serviceLocator.get<ConnectivityService>().init(),
    );
    _serviceLocator.register<PerformanceService>(PerformanceService(), 
      initializer: () => _serviceLocator.get<PerformanceService>().init(),
    );

    // Authentication and Cloud Services
    _serviceLocator.register<AuthService>(AuthService(), 
      initializer: () => _serviceLocator.get<AuthService>().init(),
    );
    _serviceLocator.register<CloudSyncService>(CloudSyncService(), 
      initializer: () => _serviceLocator.get<CloudSyncService>().init(),
    );

    // Feature Management
    _serviceLocator.register<FeatureFlagService>(FeatureFlagService(), 
      initializer: () => _serviceLocator.get<FeatureFlagService>().init(),
    );

    // User Experience Services
    _serviceLocator.register<LocalizationService>(LocalizationService(), 
      initializer: () => _serviceLocator.get<LocalizationService>().init(),
    );
    _serviceLocator.register<TutorialService>(TutorialService(), 
      initializer: () => _serviceLocator.get<TutorialService>().init(),
    );
    _serviceLocator.register<NotificationService>(NotificationService(), 
      initializer: () => _serviceLocator.get<NotificationService>().init(),
    );

    // Storage and Recording
    _serviceLocator.register<StorageService>(StorageService(), 
      initializer: () => _serviceLocator.get<StorageService>().init(),
    );
    _serviceLocator.register<RecordingService>(RecordingService(), 
      initializer: () => _serviceLocator.get<RecordingService>().init(),
    );

    // Initialize all registered services
    await _serviceLocator.initializeServices();
  }

  // Get a specific service
  static T get<T>() {
    return _serviceLocator.get<T>();
  }

  // Check if a service is registered
  static bool isRegistered<T>() {
    return _serviceLocator.isRegistered<T>();
  }

  // Dispose all services
  static void dispose() {
    _serviceLocator.disposeServices();
  }
}