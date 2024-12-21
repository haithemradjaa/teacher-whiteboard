import 'dart:async';

import 'auth_service.dart';
import 'analytics_service.dart';
import 'logging_service.dart';
import 'performance_service.dart';
import 'notification_service.dart';
import 'connectivity_service.dart';
import 'cloud_sync_service.dart';
import 'storage_service.dart';
import 'permission_service.dart';
import 'recording_service.dart';
import 'whiteboard_service.dart';
import 'lesson_service.dart';

enum ServiceInitializationStatus {
  uninitialized,
  initializing,
  initialized,
  failed
}

class ServiceInitializationResult {
  final String serviceName;
  final ServiceInitializationStatus status;
  final DateTime timestamp;
  final dynamic error;

  ServiceInitializationResult({
    required this.serviceName,
    required this.status,
    DateTime? timestamp,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();
}

class DependencyInjectionService {
  static final DependencyInjectionService _instance = DependencyInjectionService._internal();
  factory DependencyInjectionService() => _instance;
  DependencyInjectionService._internal();

  // Service instances
  final Map<Type, dynamic> _services = {};
  final Map<Type, ServiceInitializationStatus> _serviceStatus = {};

  // Initialization tracking
  final _initializationController = StreamController<ServiceInitializationResult>.broadcast();
  Stream<ServiceInitializationResult> get initializationStream => _initializationController.stream;

  // Logging and analytics
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Register a service with optional custom instance
  void register<T>(T service, {bool replaceExisting = false}) {
    if (replaceExisting || !_services.containsKey(T)) {
      _services[T] = service;
      _serviceStatus[T] = ServiceInitializationStatus.initialized;
      
      _loggingService.info('Registered service: $T');
      _analyticsService.logEvent(
        name: 'service_registered',
        parameters: {'service_type': T.toString()},
        category: AnalyticsEventCategory.systemInteraction,
      );
    }
  }

  // Retrieve a registered service
  T get<T>() {
    if (!_services.containsKey(T)) {
      _createServiceInstance<T>();
    }
    return _services[T] as T;
  }

  // Create service instance if not exists
  void _createServiceInstance<T>() {
    try {
      _serviceStatus[T] = ServiceInitializationStatus.initializing;
      
      dynamic service;
      switch (T) {
        case AuthService:
          service = AuthService();
          break;
        case AnalyticsService:
          service = AnalyticsService();
          break;
        case LoggingService:
          service = LoggingService();
          break;
        case PerformanceService:
          service = PerformanceService();
          break;
        case NotificationService:
          service = NotificationService();
          break;
        case ConnectivityService:
          service = ConnectivityService();
          break;
        case CloudSyncService:
          service = CloudSyncService();
          break;
        case StorageService:
          service = StorageService();
          break;
        case PermissionsService:
          service = PermissionsService();
          break;
        case RecordingService:
          service = RecordingService();
          break;
        case WhiteboardService:
          service = WhiteboardService();
          break;
        case LessonService:
          service = LessonService();
          break;
        default:
          throw UnsupportedError('No factory method for service type $T');
      }

      _services[T] = service;
      _serviceStatus[T] = ServiceInitializationStatus.initialized;

      _initializationController.add(ServiceInitializationResult(
        serviceName: T.toString(),
        status: ServiceInitializationStatus.initialized,
      ));

      _loggingService.info('Created service instance: $T');
    } catch (e) {
      _serviceStatus[T] = ServiceInitializationStatus.failed;
      
      _initializationController.add(ServiceInitializationResult(
        serviceName: T.toString(),
        status: ServiceInitializationStatus.failed,
        error: e,
      ));

      _loggingService.error('Failed to create service instance: $T', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  // Initialize all core services
  Future<void> initializeAllServices() async {
    _loggingService.info('Initializing all services');
    
    final servicesToInitialize = [
      AuthService,
      AnalyticsService,
      LoggingService,
      PerformanceService,
      NotificationService,
      ConnectivityService,
      CloudSyncService,
      StorageService,
      PermissionsService,
      RecordingService,
      WhiteboardService,
      LessonService,
    ];

    for (var serviceType in servicesToInitialize) {
      try {
        final service = get<dynamic>();
        
        // Call init method if exists
        if (service is AuthService) await service.init();
        if (service is AnalyticsService) await service.init();
        if (service is LoggingService) await service.init();
        if (service is PerformanceService) await service.init();
        if (service is NotificationService) await service.init();
        if (service is ConnectivityService) await service.init();
        if (service is CloudSyncService) await service.init();
        if (service is StorageService) await service.init();
        if (service is PermissionsService) await service.init();
        if (service is RecordingService) await service.init();
        if (service is WhiteboardService) await service.init();
        if (service is LessonService) await service.init();

      } catch (e) {
        _loggingService.error('Failed to initialize service: $serviceType', error: e);
        _analyticsService.recordError(e, StackTrace.current);
      }
    }

    _loggingService.info('All services initialized');
  }

  // Check initialization status of a service
  ServiceInitializationStatus getServiceStatus<T>() {
    return _serviceStatus[T] ?? ServiceInitializationStatus.uninitialized;
  }

  // Dispose all services
  void disposeAllServices() {
    _services.forEach((type, service) {
      try {
        if (service is AuthService) service.dispose();
        if (service is AnalyticsService) service.dispose();
        if (service is LoggingService) service.dispose();
        if (service is PerformanceService) service.dispose();
        if (service is NotificationService) service.dispose();
        if (service is ConnectivityService) service.dispose();
        if (service is CloudSyncService) service.dispose();
        if (service is StorageService) service.dispose();
        if (service is PermissionsService) service.dispose();
        if (service is RecordingService) service.dispose();
        if (service is WhiteboardService) service.dispose();
        if (service is LessonService) service.dispose();
      } catch (e) {
        _loggingService.error('Error disposing service: $type', error: e);
      }
    });

    _services.clear();
    _serviceStatus.clear();
    _initializationController.close();
  }
}