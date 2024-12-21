import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logging_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

enum PermissionType {
  camera,
  microphone,
  storage,
  location,
  notifications
}

class PermissionStatus {
  final PermissionType type;
  final bool isGranted;
  final DateTime timestamp;

  PermissionStatus({
    required this.type,
    required this.isGranted,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final NotificationService _notificationService = NotificationService();

  final _permissionStreamController = StreamController<PermissionStatus>.broadcast();
  Stream<PermissionStatus> get permissionStream => _permissionStreamController.stream;

  Future<bool> requestPermission(PermissionType type) async {
    try {
      Permission permission;
      switch (type) {
        case PermissionType.camera:
          permission = Permission.camera;
          break;
        case PermissionType.microphone:
          permission = Permission.microphone;
          break;
        case PermissionType.storage:
          permission = Platform.isAndroid ? Permission.storage : Permission.photos;
          break;
        case PermissionType.location:
          permission = Permission.location;
          break;
        case PermissionType.notifications:
          permission = Permission.notification;
          break;
      }

      final status = await permission.request();
      final isGranted = status.isGranted;

      // Log permission request
      _analyticsService.logEvent(
        name: 'permission_requested',
        parameters: {
          'permission_type': type.toString(),
          'granted': isGranted,
        },
        category: AnalyticsEventCategory.systemInteraction,
      );

      // Log to system
      _loggingService.info('Permission ${type.toString()} ${isGranted ? 'granted' : 'denied'}');

      // Emit permission status
      final permissionStatus = PermissionStatus(
        type: type,
        isGranted: isGranted,
      );
      _permissionStreamController.add(permissionStatus);

      // Show notification if permission denied
      if (!isGranted) {
        _notificationService.showNotification(
          title: 'Permission Required',
          body: 'Please grant ${_getPermissionDescription(type)} access in settings',
          type: NotificationType.systemUpdate,
        );
      }

      return isGranted;
    } catch (e) {
      _loggingService.error('Permission request failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> checkPermission(PermissionType type) async {
    try {
      Permission permission;
      switch (type) {
        case PermissionType.camera:
          permission = Permission.camera;
          break;
        case PermissionType.microphone:
          permission = Permission.microphone;
          break;
        case PermissionType.storage:
          permission = Platform.isAndroid ? Permission.storage : Permission.photos;
          break;
        case PermissionType.location:
          permission = Permission.location;
          break;
        case PermissionType.notifications:
          permission = Permission.notification;
          break;
      }

      final status = await permission.status;
      final isGranted = status.isGranted;

      // Emit permission status
      final permissionStatus = PermissionStatus(
        type: type,
        isGranted: isGranted,
      );
      _permissionStreamController.add(permissionStatus);

      return isGranted;
    } catch (e) {
      _loggingService.error('Permission check failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      
      _analyticsService.logEvent(
        name: 'app_settings_opened',
        category: AnalyticsEventCategory.systemInteraction,
      );
    } catch (e) {
      _loggingService.error('Failed to open app settings', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  String _getPermissionDescription(PermissionType type) {
    switch (type) {
      case PermissionType.camera:
        return 'Camera';
      case PermissionType.microphone:
        return 'Microphone';
      case PermissionType.storage:
        return 'Storage';
      case PermissionType.location:
        return 'Location';
      case PermissionType.notifications:
        return 'Notifications';
    }
  }

  void dispose() {
    _permissionStreamController.close();
  }
}