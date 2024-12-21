import 'package:permission_handler/permission_handler.dart';

class PermissionsHandler {
  static Future<bool> requestScreenRecordPermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> checkAllRecordingPermissions() async {
    final storagePermission = await Permission.storage.status;
    final microphonePermission = await Permission.microphone.status;
    final cameraPermission = await Permission.camera.status;

    return storagePermission.isGranted &&
        microphonePermission.isGranted &&
        cameraPermission.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  static Future<void> requestAllPermissions() async {
    await Permission.storage.request();
    await Permission.microphone.request();
    await Permission.camera.request();
  }
}