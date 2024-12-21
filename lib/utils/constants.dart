import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'Teacher Whiteboard';
  static const String appVersion = '1.0.0';

  // Color Palette
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF03A9F4);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // Drawing Defaults
  static const List<Color> drawingColors = [
    Colors.black,
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
  ];

  static const List<double> strokeWidths = [
    2.0,
    4.0,
    6.0,
    8.0,
    10.0,
  ];

  // Storage Paths
  static const String recordingsDirectory = 'recordings';

  // Recording Limits
  static const int maxRecordingDurationMinutes = 120; // 2 hours
  static const int maxRecordingsSaved = 50;

  // UI Dimensions
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;

  // Error Messages
  static const String permissionDeniedMessage = 'Permissions are required to record';
  static const String storageFullMessage = 'Storage is full. Please delete some recordings.';

  // Themes
  static ThemeData get lightTheme => ThemeData(
    primarySwatch: Colors.blue,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      color: primaryColor,
      elevation: 0,
    ),
    scaffoldBackgroundColor: backgroundColor,
  );
}