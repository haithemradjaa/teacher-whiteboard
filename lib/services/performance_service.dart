import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

import 'logging_service.dart';
import 'analytics_service.dart';
import 'connectivity_service.dart';

enum PerformanceMetricType {
  startupTime,
  screenTransition,
  networkRequest,
  databaseOperation,
  renderTime,
  customTrace
}

class PerformanceMetric {
  final PerformanceMetricType type;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic> metadata;

  PerformanceMetric({
    required this.type,
    required this.name,
    DateTime? startTime,
    this.endTime,
    this.metadata = const {},
  }) : startTime = startTime ?? DateTime.now();

  Duration get duration => endTime != null 
    ? endTime!.difference(startTime) 
    : Duration.zero;

  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'name': name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'duration': duration.inMilliseconds,
    'metadata': metadata,
  };
}

class DevicePerformanceInfo {
  final int availableMemory;
  final int totalMemory;
  final double cpuUsage;
  final String deviceModel;
  final String osVersion;

  DevicePerformanceInfo({
    required this.availableMemory,
    required this.totalMemory,
    required this.cpuUsage,
    required this.deviceModel,
    required this.osVersion,
  });

  Map<String, dynamic> toJson() => {
    'availableMemory': availableMemory,
    'totalMemory': totalMemory,
    'cpuUsage': cpuUsage,
    'deviceModel': deviceModel,
    'osVersion': osVersion,
  };
}

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  final _performanceMetricsController = StreamController<PerformanceMetric>.broadcast();
  final _devicePerformanceController = StreamController<DevicePerformanceInfo>.broadcast();

  Stream<PerformanceMetric> get performanceMetricsStream => _performanceMetricsController.stream;
  Stream<DevicePerformanceInfo> get devicePerformanceStream => _devicePerformanceController.stream;

  final Map<String, PerformanceMetric> _activeTraces = {};

  Future<void> init() async {
    try {
      // Initial device performance snapshot
      await captureDevicePerformance();

      _loggingService.info('Performance service initialized');
    } catch (e) {
      _loggingService.error('Performance service initialization failed', error: e);
    }
  }

  Future<void> startTrace(String traceName, {
    PerformanceMetricType type = PerformanceMetricType.customTrace,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final metric = PerformanceMetric(
        type: type,
        name: traceName,
        metadata: metadata ?? {},
      );

      _activeTraces[traceName] = metric;
      _performanceMetricsController.add(metric);

      _analyticsService.startPerformanceTrace(traceName);
      _loggingService.info('Performance trace started: $traceName');
    } catch (e) {
      _loggingService.error('Failed to start performance trace', error: e);
    }
  }

  Future<PerformanceMetric?> stopTrace(String traceName) async {
    try {
      final metric = _activeTraces.remove(traceName);
      
      if (metric != null) {
        final endMetric = PerformanceMetric(
          type: metric.type,
          name: metric.name,
          startTime: metric.startTime,
          endTime: DateTime.now(),
          metadata: metric.metadata,
        );

        _performanceMetricsController.add(endMetric);
        _analyticsService.stopPerformanceTrace(traceName);

        _loggingService.info(
          'Performance trace completed: $traceName, '
          'Duration: ${endMetric.duration.inMilliseconds}ms'
        );

        return endMetric;
      }

      return null;
    } catch (e) {
      _loggingService.error('Failed to stop performance trace', error: e);
      return null;
    }
  }

  Future<DevicePerformanceInfo> captureDevicePerformance() async {
    try {
      int availableMemory = 0;
      int totalMemory = 0;
      double cpuUsage = 0.0;
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceModel = androidInfo.model;
        osVersion = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceModel = iosInfo.model;
        osVersion = iosInfo.systemVersion;
      }

      final devicePerformance = DevicePerformanceInfo(
        availableMemory: availableMemory,
        totalMemory: totalMemory,
        cpuUsage: cpuUsage,
        deviceModel: deviceModel,
        osVersion: osVersion,
      );

      _devicePerformanceController.add(devicePerformance);

      _analyticsService.logEvent(
        name: 'device_performance_captured',
        parameters: devicePerformance.toJson(),
        category: AnalyticsEventCategory.performance,
      );

      return devicePerformance;
    } catch (e) {
      _loggingService.error('Failed to capture device performance', error: e);
      rethrow;
    }
  }

  Future<void> trackStartupPerformance(VoidCallback startupLogic) async {
    final startTime = DateTime.now();

    try {
      await startupLogic();

      final endTime = DateTime.now();
      final startupDuration = endTime.difference(startTime);

      final startupMetric = PerformanceMetric(
        type: PerformanceMetricType.startupTime,
        name: 'app_startup',
        startTime: startTime,
        endTime: endTime,
        metadata: {
          'network_status': await _connectivityService.getConnectionType(),
        },
      );

      _performanceMetricsController.add(startupMetric);

      _analyticsService.logEvent(
        name: 'app_startup_performance',
        parameters: {
          'startup_duration_ms': startupDuration.inMilliseconds,
        },
        category: AnalyticsEventCategory.performance,
      );

      _loggingService.info(
        'App startup completed in ${startupDuration.inMilliseconds}ms'
      );
    } catch (e) {
      _loggingService.error('Startup performance tracking failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  void dispose() {
    _performanceMetricsController.close();
    _devicePerformanceController.close();
  }
}