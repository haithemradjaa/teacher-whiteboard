import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';

import 'logging_service.dart';
import 'analytics_service.dart';
import 'auth_service.dart';

enum NotificationType {
  recording,
  cloudSync,
  tutorial,
  systemUpdate,
  reminder
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    DateTime? timestamp,
    this.payload,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthService _authService = AuthService();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();

  // Notification stream controllers
  final _notificationController = BehaviorSubject<AppNotification>();
  Stream<AppNotification> get notificationStream => _notificationController.stream;

  // Notification settings
  late NotificationDetails _defaultNotificationDetails;

  Future<void> init() async {
    try {
      // Initialize notification plugin
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestSoundPermission: false,
        requestBadgePermission: false,
        requestAlertPermission: false,
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Configure default notification style
      _defaultNotificationDetails = const NotificationDetails(
        android: AndroidNotificationDetails(
          'teacher_whiteboard_channel',
          'Teacher Whiteboard Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      _loggingService.info('Notification service initialized');
    } catch (e) {
      _loggingService.error('Notification service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  // Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.systemUpdate,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      final notification = AppNotification(
        id: notificationId.toString(),
        title: title,
        body: body,
        type: type,
        payload: payload,
      );

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        _defaultNotificationDetails,
        payload: _encodePayload(payload),
      );

      // Add to notification stream
      _notificationController.add(notification);

      // Log notification
      _analyticsService.logEvent(
        name: 'notification_displayed',
        parameters: {
          'type': type.toString(),
          'title': title,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Notification shown: $title');
    } catch (e) {
      _loggingService.error('Failed to show notification', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse details) {
    try {
      final payload = _decodePayload(details.payload);

      final notification = AppNotification(
        id: details.id.toString(),
        title: payload?['title'] ?? 'Notification',
        body: payload?['body'] ?? '',
        type: _parseNotificationType(payload?['type']),
        payload: payload,
      );

      _notificationController.add(notification);

      _analyticsService.logEvent(
        name: 'notification_tapped',
        parameters: {
          'type': notification.type.toString(),
          'title': notification.title,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Notification tapped: ${notification.title}');
    } catch (e) {
      _loggingService.error('Error handling notification tap', error: e);
    }
  }

  // Encode payload for notification
  String? _encodePayload(Map<String, dynamic>? payload) {
    return payload != null ? payload.toString() : null;
  }

  // Decode payload from notification
  Map<String, dynamic>? _decodePayload(String? payloadString) {
    if (payloadString == null) return null;
    try {
      // Basic parsing, can be enhanced
      return Map<String, dynamic>.from(
        payloadString.split(',').map((item) {
          final parts = item.split(':');
          return MapEntry(parts[0].trim(), parts[1].trim());
        }).toMap(),
      );
    } catch (e) {
      return null;
    }
  }

  // Parse notification type from string
  NotificationType _parseNotificationType(String? typeString) {
    return NotificationType.values.firstWhere(
      (type) => type.toString() == typeString,
      orElse: () => NotificationType.systemUpdate,
    );
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    NotificationType type = NotificationType.reminder,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _flutterLocalNotificationsPlugin.schedule(
        notificationId,
        title,
        body,
        scheduledTime,
        _defaultNotificationDetails,
        payload: _encodePayload(payload),
      );

      _loggingService.info('Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      _loggingService.error('Failed to schedule notification', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  // Cancel a specific notification
  Future<void> cancelNotification(String notificationId) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(int.parse(notificationId));
      _loggingService.info('Notification canceled: $notificationId');
    } catch (e) {
      _loggingService.error('Failed to cancel notification', error: e);
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      _loggingService.info('All notifications canceled');
    } catch (e) {
      _loggingService.error('Failed to cancel all notifications', error: e);
    }
  }

  void dispose() {
    _notificationController.close();
  }
}