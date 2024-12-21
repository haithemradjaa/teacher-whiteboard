import 'dart:async';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

enum FeatureFlag {
  // Recording features
  screenRecording,
  audioRecording,
  multiTrackRecording,
  
  // UI/UX features
  darkMode,
  compactView,
  
  // Advanced features
  cloudSync,
  aiTranscription,
  
  // Experimental features
  betaWhiteboard,
  advancedEditing,
  
  // Performance and privacy
  performanceTracking,
  crashReporting
}

class FeatureFlagStatus {
  final FeatureFlag flag;
  final bool isEnabled;
  final dynamic value;
  final DateTime lastUpdated;

  FeatureFlagStatus({
    required this.flag,
    required this.isEnabled,
    this.value,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  late FirebaseRemoteConfig _remoteConfig;

  // Feature flag status stream
  final _featureFlagStatusController = StreamController<FeatureFlagStatus>.broadcast();
  Stream<FeatureFlagStatus> get featureFlagStatusStream => _featureFlagStatusController.stream;

  // Cached feature flag statuses
  final Map<FeatureFlag, FeatureFlagStatus> _cachedFeatureFlags = {};

  Future<void> init() async {
    try {
      // Initialize Firebase Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Configure Remote Config settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set default feature flag values
      await _setDefaultFeatureFlags();

      // Fetch and activate remote config
      await fetchAndActivateRemoteConfig();

      _loggingService.info('Feature flag service initialized');
    } catch (e) {
      _loggingService.error('Feature flag service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> _setDefaultFeatureFlags() async {
    await _remoteConfig.setDefaults({
      // Recording features
      'screenRecording': true,
      'audioRecording': true,
      'multiTrackRecording': false,
      
      // UI/UX features
      'darkMode': false,
      'compactView': false,
      
      // Advanced features
      'cloudSync': true,
      'aiTranscription': false,
      
      // Experimental features
      'betaWhiteboard': false,
      'advancedEditing': false,
      
      // Performance and privacy
      'performanceTracking': true,
      'crashReporting': true,
    });
  }

  Future<void> fetchAndActivateRemoteConfig() async {
    try {
      // Fetch and activate remote config
      final updated = await _remoteConfig.fetchAndActivate();

      if (updated) {
        _loggingService.info('Remote config updated');
        _analyticsService.logEvent(
          name: 'remote_config_updated',
          category: AnalyticsEventCategory.userInteraction,
        );
      }

      // Update cached feature flags
      await _updateCachedFeatureFlags();
    } catch (e) {
      _loggingService.error('Failed to fetch remote config', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> _updateCachedFeatureFlags() async {
    for (var flag in FeatureFlag.values) {
      final status = _getFeatureFlagStatus(flag);
      _cachedFeatureFlags[flag] = status;
      _featureFlagStatusController.add(status);
    }
  }

  FeatureFlagStatus _getFeatureFlagStatus(FeatureFlag flag) {
    try {
      final flagName = flag.toString().split('.').last;
      final isEnabled = _remoteConfig.getBool(flagName);
      
      return FeatureFlagStatus(
        flag: flag,
        isEnabled: isEnabled,
        value: isEnabled,
      );
    } catch (e) {
      _loggingService.error('Failed to get feature flag status', error: e);
      return FeatureFlagStatus(
        flag: flag,
        isEnabled: false,
      );
    }
  }

  bool isFeatureEnabled(FeatureFlag flag) {
    return _cachedFeatureFlags[flag]?.isEnabled ?? false;
  }

  Future<FeatureFlagStatus> getFeatureFlagStatus(FeatureFlag flag) async {
    // Ensure remote config is up to date
    await fetchAndActivateRemoteConfig();
    return _cachedFeatureFlags[flag] ?? FeatureFlagStatus(
      flag: flag,
      isEnabled: false,
    );
  }

  Stream<FeatureFlagStatus> watchFeatureFlag(FeatureFlag flag) {
    return featureFlagStatusStream.where((status) => status.flag == flag);
  }

  Future<void> overrideFeatureFlag(FeatureFlag flag, bool value) async {
    try {
      final flagName = flag.toString().split('.').last;
      await _remoteConfig.setValue(flagName, value);

      // Update cached feature flags
      await _updateCachedFeatureFlags();

      _analyticsService.logEvent(
        name: 'feature_flag_overridden',
        parameters: {
          'flag': flagName,
          'value': value,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Feature flag overridden: $flagName = $value');
    } catch (e) {
      _loggingService.error('Failed to override feature flag', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> resetFeatureFlags() async {
    try {
      // Reset to default values
      await _setDefaultFeatureFlags();
      await fetchAndActivateRemoteConfig();

      _analyticsService.logEvent(
        name: 'feature_flags_reset',
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Feature flags reset to defaults');
    } catch (e) {
      _loggingService.error('Failed to reset feature flags', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  void dispose() {
    _featureFlagStatusController.close();
    _cachedFeatureFlags.clear();
  }
}