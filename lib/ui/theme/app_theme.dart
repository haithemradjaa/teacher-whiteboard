import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette
  static const Color _primaryColor = Color(0xFF3498db);      // Vibrant Blue
  static const Color _secondaryColor = Color(0xFF2ecc71);    // Bright Green
  static const Color _accentColor = Color(0xFFe74c3c);       // Vivid Red
  static const Color _backgroundColor = Color(0xFFF5F5F5);   // Light Gray
  static const Color _textColor = Color(0xFF333333);         // Dark Gray

  // Typography
  static final TextTheme _textTheme = TextTheme(
    headline1: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: _textColor,
      letterSpacing: -1.5,
    ),
    headline2: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: _textColor,
      letterSpacing: -1.0,
    ),
    headline3: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: _textColor,
      letterSpacing: -0.5,
    ),
    headline4: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      color: _textColor,
      letterSpacing: 0.25,
    ),
    headline5: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      color: _textColor,
    ),
    headline6: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: _textColor,
      letterSpacing: 0.15,
    ),
    bodyText1: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: _textColor,
      letterSpacing: 0.5,
    ),
    bodyText2: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: _textColor,
      letterSpacing: 0.25,
    ),
  );

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _backgroundColor,
    colorScheme: ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _accentColor,
      background: _backgroundColor,
    ),
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      color: _primaryColor,
      elevation: 4,
      titleTextStyle: _textTheme.headline6?.copyWith(color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        primary: _primaryColor,
        onPrimary: Colors.white,
        textStyle: _textTheme.button?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      labelStyle: _textTheme.bodyText1,
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: Color(0xFF121212),
    colorScheme: ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _accentColor,
      background: Color(0xFF121212),
    ),
    textTheme: _textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      color: _primaryColor.withOpacity(0.9),
      elevation: 4,
      titleTextStyle: _textTheme.headline6?.copyWith(color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        primary: _primaryColor.withOpacity(0.9),
        onPrimary: Colors.white,
        textStyle: _textTheme.button?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      labelStyle: _textTheme.bodyText1?.copyWith(color: Colors.white70),
    ),
  );
}