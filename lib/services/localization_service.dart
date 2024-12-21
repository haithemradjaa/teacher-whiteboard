import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

class AppLocale {
  final String languageCode;
  final String? countryCode;
  final String displayName;
  final String nativeName;

  const AppLocale({
    required this.languageCode,
    this.countryCode,
    required this.displayName,
    required this.nativeName,
  });

  Locale get locale => Locale(languageCode, countryCode);

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'countryCode': countryCode,
    'displayName': displayName,
    'nativeName': nativeName,
  };
}

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  static const List<AppLocale> supportedLocales = [
    AppLocale(
      languageCode: 'en',
      countryCode: 'US',
      displayName: 'English (United States)',
      nativeName: 'English',
    ),
    AppLocale(
      languageCode: 'es',
      countryCode: 'ES',
      displayName: 'Spanish (Spain)',
      nativeName: 'Español',
    ),
    AppLocale(
      languageCode: 'fr',
      countryCode: 'FR',
      displayName: 'French (France)',
      nativeName: 'Français',
    ),
    AppLocale(
      languageCode: 'de',
      countryCode: 'DE',
      displayName: 'German (Germany)',
      nativeName: 'Deutsch',
    ),
  ];

  static const AppLocale defaultLocale = AppLocale(
    languageCode: 'en',
    countryCode: 'US',
    displayName: 'English (United States)',
    nativeName: 'English',
  );

  final _localeController = StreamController<AppLocale>.broadcast();
  Stream<AppLocale> get localeStream => _localeController.stream;

  AppLocale? _currentLocale;
  AppLocale get currentLocale => _currentLocale ?? defaultLocale;

  Future<void> init() async {
    try {
      await _loadSavedLocale();
      _loggingService.info('Localization service initialized');
    } catch (e) {
      _loggingService.error('Localization service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocaleJson = prefs.getString('app_locale');

      if (savedLocaleJson != null) {
        final savedLocale = AppLocale.fromJson(json.decode(savedLocaleJson));
        await setLocale(savedLocale);
      } else {
        // Detect system locale
        final systemLocale = _detectSystemLocale();
        await setLocale(systemLocale);
      }
    } catch (e) {
      _loggingService.warning('Failed to load saved locale, using default', error: e);
      await setLocale(defaultLocale);
    }
  }

  AppLocale _detectSystemLocale() {
    try {
      final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
      
      final matchedLocale = supportedLocales.firstWhere(
        (locale) => 
          locale.languageCode == platformLocale.languageCode &&
          (locale.countryCode == platformLocale.countryCode || locale.countryCode == null),
        orElse: () => defaultLocale,
      );

      return matchedLocale;
    } catch (e) {
      _loggingService.warning('Locale detection failed', error: e);
      return defaultLocale;
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    try {
      if (_currentLocale == locale) return;

      _currentLocale = locale;
      _localeController.add(locale);

      // Persist locale
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', json.encode(locale.toJson()));

      _analyticsService.logEvent(
        name: 'language_changed',
        parameters: {
          'language_code': locale.languageCode,
          'country_code': locale.countryCode,
          'display_name': locale.displayName,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Language changed to: ${locale.displayName}');
    } catch (e) {
      _loggingService.error('Failed to set locale', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  List<LocalizationsDelegate> get localizationDelegates => [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  List<Locale> get supportedLocalesList => 
    supportedLocales.map((locale) => locale.locale).toList();

  AppLocale? getLocaleByCode(String languageCode, {String? countryCode}) {
    try {
      return supportedLocales.firstWhere(
        (locale) => 
          locale.languageCode == languageCode && 
          (countryCode == null || locale.countryCode == countryCode)
      );
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _localeController.close();
  }

  // Static extension methods for JSON serialization
  static AppLocale fromJson(Map<String, dynamic> json) => AppLocale(
    languageCode: json['languageCode'],
    countryCode: json['countryCode'],
    displayName: json['displayName'],
    nativeName: json['nativeName'],
  );
}