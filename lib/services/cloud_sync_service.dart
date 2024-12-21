import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import 'auth_service.dart';
import 'connectivity_service.dart';
import 'logging_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

enum SyncStatus {
  idle,
  uploading,
  downloading,
  synced,
  failed
}

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final NotificationService _notificationService = NotificationService();

  final _syncStreamController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStream => _syncStreamController.stream;

  Future<String?> uploadRecording(File recordingFile) async {
    try {
      // Check connectivity
      if (!await _connectivityService.isConnected()) {
        _notificationService.showNotification(
          title: 'Sync Failed',
          body: 'No internet connection. Upload postponed.',
          type: NotificationType.systemUpdate,
        );
        return null;
      }

      // Ensure user is authenticated
      final user = _authService.currentUser;
      if (user == null) {
        _loggingService.error('Upload failed: User not authenticated');
        return null;
      }

      _syncStreamController.add(SyncStatus.uploading);

      // Generate unique filename
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}${path.extension(recordingFile.path)}';
      final storageReference = _storage.ref().child('recordings/$fileName');

      // Upload file
      final uploadTask = await storageReference.putFile(recordingFile);
      final downloadURL = await uploadTask.ref.getDownloadURL();

      // Log analytics
      _analyticsService.logEvent(
        name: 'recording_uploaded',
        parameters: {
          'file_size': recordingFile.lengthSync(),
          'file_type': path.extension(recordingFile.path),
        },
        category: AnalyticsEventCategory.fileManagement,
      );

      _syncStreamController.add(SyncStatus.synced);
      
      _notificationService.showNotification(
        title: 'Upload Complete',
        body: 'Recording successfully uploaded',
        type: NotificationType.cloudSync,
      );

      return downloadURL;
    } catch (e) {
      _loggingService.error('Recording upload failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      
      _syncStreamController.add(SyncStatus.failed);
      
      _notificationService.showNotification(
        title: 'Upload Failed',
        body: 'Unable to upload recording',
        type: NotificationType.systemUpdate,
      );

      return null;
    }
  }

  Future<File?> downloadRecording(String downloadURL, String localPath) async {
    try {
      // Check connectivity
      if (!await _connectivityService.isConnected()) {
        _notificationService.showNotification(
          title: 'Download Failed',
          body: 'No internet connection',
          type: NotificationType.systemUpdate,
        );
        return null;
      }

      _syncStreamController.add(SyncStatus.downloading);

      // Download file
      final File localFile = File(localPath);
      await FirebaseStorage.instance
        .refFromURL(downloadURL)
        .writeToFile(localFile);

      _syncStreamController.add(SyncStatus.synced);
      
      _notificationService.showNotification(
        title: 'Download Complete',
        body: 'Recording downloaded successfully',
        type: NotificationType.cloudSync,
      );

      return localFile;
    } catch (e) {
      _loggingService.error('Recording download failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      
      _syncStreamController.add(SyncStatus.failed);
      
      _notificationService.showNotification(
        title: 'Download Failed',
        body: 'Unable to download recording',
        type: NotificationType.systemUpdate,
      );

      return null;
    }
  }

  void dispose() {
    _syncStreamController.close();
  }
}