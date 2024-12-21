import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:screen_recorder/screen_recorder.dart';

import 'permission_service.dart';
import 'storage_service.dart';
import 'cloud_sync_service.dart';
import 'logging_service.dart';
import 'analytics_service.dart';
import 'notification_service.dart';
import 'performance_service.dart';

enum RecordingMode {
  audioOnly,
  screenWithAudio,
  videoWithAudio
}

enum RecordingState {
  idle,
  preparing,
  recording,
  paused,
  stopping,
  completed
}

class RecordingMetadata {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final RecordingMode mode;
  final String filePath;
  final int fileSizeBytes;
  final Duration duration;

  RecordingMetadata({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.mode,
    required this.filePath,
    required this.fileSizeBytes,
    required this.duration,
  });
}

class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final PermissionsService _permissionsService = PermissionsService();
  final StorageService _storageService = StorageService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final NotificationService _notificationService = NotificationService();
  final PerformanceService _performanceService = PerformanceService();

  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final ScreenRecorder _screenRecorder = ScreenRecorder();

  final _recordingStateController = StreamController<RecordingState>.broadcast();
  final _recordingMetadataController = StreamController<RecordingMetadata>.broadcast();

  Stream<RecordingState> get recordingStateStream => _recordingStateController.stream;
  Stream<RecordingMetadata> get recordingMetadataStream => _recordingMetadataController.stream;

  RecordingState _currentState = RecordingState.idle;
  RecordingMetadata? _currentRecording;

  Future<void> init() async {
    try {
      await _audioRecorder.openRecorder();
      _loggingService.info('Recording service initialized');
    } catch (e) {
      _loggingService.error('Recording service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<bool> startRecording({
    RecordingMode mode = RecordingMode.audioOnly,
    String? customFileName,
  }) async {
    try {
      // Check and request necessary permissions
      final micPermission = await _permissionsService.checkPermission(PermissionType.microphone);
      final storagePermission = await _permissionsService.checkPermission(PermissionType.storage);

      if (!micPermission || !storagePermission) {
        _notificationService.showNotification(
          title: 'Permission Required',
          body: 'Please grant microphone and storage permissions',
          type: NotificationType.systemUpdate,
        );
        return false;
      }

      _recordingStateController.add(RecordingState.preparing);

      // Prepare storage location
      final recordingsDir = await _storageService.getRecordingsDirectory();
      final timestamp = DateTime.now();
      final fileName = customFileName ?? 'recording_${timestamp.toIso8601String().replaceAll(':', '-')}';
      final filePath = '${recordingsDir.path}/$fileName.mp4';

      switch (mode) {
        case RecordingMode.audioOnly:
          await _startAudioRecording(filePath);
          break;
        case RecordingMode.screenWithAudio:
          await _startScreenRecording(filePath);
          break;
        case RecordingMode.videoWithAudio:
          // Implement video recording logic
          throw UnimplementedError('Video recording not yet supported');
      }

      _currentRecording = RecordingMetadata(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: timestamp,
        mode: mode,
        filePath: filePath,
        fileSizeBytes: 0,
        duration: Duration.zero,
      );

      _recordingStateController.add(RecordingState.recording);

      _analyticsService.logEvent(
        name: 'recording_started',
        parameters: {
          'mode': mode.toString(),
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      return true;
    } catch (e) {
      _loggingService.error('Recording start failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      _recordingStateController.add(RecordingState.idle);
      return false;
    }
  }

  Future<void> _startAudioRecording(String filePath) async {
    await _audioRecorder.startRecorder(
      toFile: filePath,
      codec: Codec.aacMP4,
    );
  }

  Future<void> _startScreenRecording(String filePath) async {
    await _screenRecorder.startRecording(
      path: filePath,
      audioEnabled: true,
    );
  }

  Future<RecordingMetadata?> stopRecording() async {
    try {
      if (_currentRecording == null) return null;

      _recordingStateController.add(RecordingState.stopping);

      final recordingFile = File(_currentRecording!.filePath);
      final endTime = DateTime.now();
      final duration = endTime.difference(_currentRecording!.startTime);

      // Stop recording based on mode
      switch (_currentRecording!.mode) {
        case RecordingMode.audioOnly:
          await _audioRecorder.stopRecorder();
          break;
        case RecordingMode.screenWithAudio:
          await _screenRecorder.stopRecording();
          break;
        case RecordingMode.videoWithAudio:
          throw UnimplementedError('Video recording not yet supported');
      }

      // Get file size
      final fileStat = await recordingFile.stat();

      // Update recording metadata
      _currentRecording = RecordingMetadata(
        id: _currentRecording!.id,
        startTime: _currentRecording!.startTime,
        endTime: endTime,
        mode: _currentRecording!.mode,
        filePath: _currentRecording!.filePath,
        fileSizeBytes: fileStat.size,
        duration: duration,
      );

      // Save to storage
      await _storageService.saveFile(
        file: recordingFile,
        location: StorageLocation.recordings,
      );

      // Cloud sync
      await _cloudSyncService.uploadRecording(recordingFile);

      _recordingStateController.add(RecordingState.completed);
      _recordingMetadataController.add(_currentRecording!);

      _analyticsService.logEvent(
        name: 'recording_stopped',
        parameters: {
          'duration_seconds': duration.inSeconds,
          'file_size_bytes': fileStat.size,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      return _currentRecording;
    } catch (e) {
      _loggingService.error('Recording stop failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      _recordingStateController.add(RecordingState.idle);
      return null;
    }
  }

  Future<void> pauseRecording() async {
    try {
      if (_currentRecording == null) return;

      switch (_currentRecording!.mode) {
        case RecordingMode.audioOnly:
          await _audioRecorder.pauseRecorder();
          break;
        case RecordingMode.screenWithAudio:
          await _screenRecorder.pauseRecording();
          break;
        case RecordingMode.videoWithAudio:
          throw UnimplementedError('Video recording not yet supported');
      }

      _recordingStateController.add(RecordingState.paused);
    } catch (e) {
      _loggingService.error('Recording pause failed', error: e);
    }
  }

  Future<void> resumeRecording() async {
    try {
      if (_currentRecording == null) return;

      switch (_currentRecording!.mode) {
        case RecordingMode.audioOnly:
          await _audioRecorder.resumeRecorder();
          break;
        case RecordingMode.screenWithAudio:
          await _screenRecorder.resumeRecording();
          break;
        case RecordingMode.videoWithAudio:
          throw UnimplementedError('Video recording not yet supported');
      }

      _recordingStateController.add(RecordingState.recording);
    } catch (e) {
      _loggingService.error('Recording resume failed', error: e);
    }
  }

  void dispose() {
    _audioRecorder.closeRecorder();
    _recordingStateController.close();
    _recordingMetadataController.close();
  }
}