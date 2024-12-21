import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

enum NetworkConnectionType {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  other,
  none
}

class NetworkQualityInfo {
  final NetworkConnectionType connectionType;
  final bool isConnected;
  final int signalStrength;
  final double downloadSpeed;
  final double uploadSpeed;
  final int latency;

  NetworkQualityInfo({
    required this.connectionType,
    required this.isConnected,
    this.signalStrength = 0,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.latency = 0,
  });

  Map<String, dynamic> toJson() => {
    'connectionType': connectionType.toString(),
    'isConnected': isConnected,
    'signalStrength': signalStrength,
    'downloadSpeed': downloadSpeed,
    'uploadSpeed': uploadSpeed,
    'latency': latency,
  };
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  final _networkStatusController = StreamController<NetworkQualityInfo>.broadcast();
  Stream<NetworkQualityInfo> get networkStatusStream => _networkStatusController.stream;

  NetworkQualityInfo? _lastNetworkStatus;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> init() async {
    try {
      // Initial connectivity check
      await checkConnectivity();

      // Start listening to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          _loggingService.error('Connectivity monitoring error', error: error);
          _analyticsService.recordError(error, StackTrace.current);
        },
      );

      _loggingService.info('Connectivity service initialized');
    } catch (e) {
      _loggingService.error('Connectivity service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<NetworkQualityInfo> checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final networkStatus = _mapConnectivityToNetworkQuality(connectivityResult);

      _lastNetworkStatus = networkStatus;
      _networkStatusController.add(networkStatus);

      _analyticsService.logEvent(
        name: 'network_status_check',
        parameters: networkStatus.toJson(),
        category: AnalyticsEventCategory.systemInteraction,
      );

      _loggingService.info(
        'Network status: ${networkStatus.connectionType}, '
        'Connected: ${networkStatus.isConnected}'
      );

      return networkStatus;
    } catch (e) {
      _loggingService.error('Failed to check connectivity', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      
      return NetworkQualityInfo(
        connectionType: NetworkConnectionType.none,
        isConnected: false,
      );
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final networkStatus = _mapConnectivityToNetworkQuality(results);

    if (_lastNetworkStatus == null || 
        _lastNetworkStatus!.connectionType != networkStatus.connectionType) {
      _analyticsService.logEvent(
        name: 'network_connection_changed',
        parameters: {
          'previous_type': _lastNetworkStatus?.connectionType.toString(),
          'current_type': networkStatus.connectionType.toString(),
        },
        category: AnalyticsEventCategory.systemInteraction,
      );
    }

    _lastNetworkStatus = networkStatus;
    _networkStatusController.add(networkStatus);
  }

  NetworkQualityInfo _mapConnectivityToNetworkQuality(List<ConnectivityResult> results) {
    final connectivityResult = results.first;
    NetworkConnectionType connectionType;
    bool isConnected = true;

    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        connectionType = NetworkConnectionType.wifi;
        break;
      case ConnectivityResult.mobile:
        connectionType = NetworkConnectionType.mobile;
        break;
      case ConnectivityResult.ethernet:
        connectionType = NetworkConnectionType.ethernet;
        break;
      case ConnectivityResult.bluetooth:
        connectionType = NetworkConnectionType.bluetooth;
        break;
      case ConnectivityResult.vpn:
        connectionType = NetworkConnectionType.vpn;
        break;
      case ConnectivityResult.other:
        connectionType = NetworkConnectionType.other;
        break;
      case ConnectivityResult.none:
        connectionType = NetworkConnectionType.none;
        isConnected = false;
        break;
    }

    return NetworkQualityInfo(
      connectionType: connectionType,
      isConnected: isConnected,
    );
  }

  Future<NetworkConnectionType> getConnectionType() async {
    final results = await _connectivity.checkConnectivity();
    return _mapConnectivityToNetworkQuality(results).connectionType;
  }

  bool get isConnected => _lastNetworkStatus?.isConnected ?? false;

  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}