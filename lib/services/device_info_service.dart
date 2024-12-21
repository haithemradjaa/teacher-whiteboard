import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'logging_service.dart';
import 'analytics_service.dart';
import 'performance_service.dart';

enum DeviceType {
  phone,
  tablet,
  desktop,
  web,
  unknown
}

class DeviceDetails {
  final String deviceId;
  final String model;
  final String osVersion;
  final DeviceType deviceType;
  final int totalMemory;
  final int availableMemory;
  final int storageTotal;
  final int storageAvailable;
  final bool isPhysicalDevice;
  final String manufacturer;
  final Map<String, dynamic> additionalDetails;

  DeviceDetails({
    required this.deviceId,
    required this.model,
    required this.osVersion,
    required this.deviceType,
    required this.totalMemory,
    required this.availableMemory,
    required this.storageTotal,
    required this.storageAvailable,
    required this.isPhysicalDevice,
    required this.manufacturer,
    this.additionalDetails = const {},
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'model': model,
    'osVersion': osVersion,
    'deviceType': deviceType.toString(),
    'totalMemory': totalMemory,
    'availableMemory': availableMemory,
    'storageTotal': storageTotal,
    'storageAvailable': storageAvailable,
    'isPhysicalDevice': isPhysicalDevice,
    'manufacturer': manufacturer,
    'additionalDetails': additionalDetails,
  };
}

class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final PerformanceService _performanceService = PerformanceService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  final _deviceDetailsController = StreamController<DeviceDetails>.broadcast();
  Stream<DeviceDetails> get deviceDetailsStream => _deviceDetailsController.stream;

  DeviceDetails? _cachedDeviceDetails;

  Future<void> init() async {
    try {
      await getDeviceInfo();
      _loggingService.info('Device info service initialized');
    } catch (e) {
      _loggingService.error('Device info service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<DeviceDetails> getDeviceInfo() async {
    try {
      if (_cachedDeviceDetails != null) return _cachedDeviceDetails!;

      DeviceDetails deviceDetails;

      if (kIsWeb) {
        deviceDetails = await _getWebDeviceInfo();
      } else if (Platform.isAndroid) {
        deviceDetails = await _getAndroidDeviceInfo();
      } else if (Platform.isIOS) {
        deviceDetails = await _getIOSDeviceInfo();
      } else if (Platform.isWindows) {
        deviceDetails = await _getWindowsDeviceInfo();
      } else if (Platform.isMacOS) {
        deviceDetails = await _getMacOSDeviceInfo();
      } else if (Platform.isLinux) {
        deviceDetails = await _getLinuxDeviceInfo();
      } else {
        deviceDetails = _getDefaultDeviceInfo();
      }

      _cachedDeviceDetails = deviceDetails;
      _deviceDetailsController.add(deviceDetails);

      _analyticsService.logEvent(
        name: 'device_info_retrieved',
        parameters: deviceDetails.toJson(),
        category: AnalyticsEventCategory.systemInteraction,
      );

      return deviceDetails;
    } catch (e) {
      _loggingService.error('Failed to retrieve device info', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      return _getDefaultDeviceInfo();
    }
  }

  Future<DeviceDetails> _getWebDeviceInfo() async {
    final webInfo = await _deviceInfo.webBrowserInfo;
    return DeviceDetails(
      deviceId: webInfo.browserName.toString(),
      model: '${webInfo.browserName} ${webInfo.appVersion}',
      osVersion: webInfo.platform ?? 'Unknown',
      deviceType: DeviceType.web,
      totalMemory: 0,
      availableMemory: 0,
      storageTotal: 0,
      storageAvailable: 0,
      isPhysicalDevice: false,
      manufacturer: 'Web Browser',
      additionalDetails: {
        'browser_name': webInfo.browserName.toString(),
        'app_version': webInfo.appVersion,
        'user_agent': webInfo.userAgent,
      },
    );
  }

  Future<DeviceDetails> _getAndroidDeviceInfo() async {
    final androidInfo = await _deviceInfo.androidInfo;
    return DeviceDetails(
      deviceId: androidInfo.id,
      model: androidInfo.model,
      osVersion: androidInfo.version.release,
      deviceType: _determineDeviceType(androidInfo.screenSize),
      totalMemory: androidInfo.totalMemoryInBytes ?? 0,
      availableMemory: 0, // Requires additional system calls
      storageTotal: 0, // Requires additional system calls
      storageAvailable: 0, // Requires additional system calls
      isPhysicalDevice: androidInfo.isPhysicalDevice,
      manufacturer: androidInfo.manufacturer,
      additionalDetails: {
        'android_id': androidInfo.androidId,
        'board': androidInfo.board,
        'bootloader': androidInfo.bootloader,
        'device': androidInfo.device,
      },
    );
  }

  Future<DeviceDetails> _getIOSDeviceInfo() async {
    final iosInfo = await _deviceInfo.iosInfo;
    return DeviceDetails(
      deviceId: iosInfo.identifierForVendor ?? 'Unknown',
      model: iosInfo.model,
      osVersion: iosInfo.systemVersion,
      deviceType: _determineDeviceType(iosInfo.screenSize),
      totalMemory: 0, // Requires additional system calls
      availableMemory: 0, // Requires additional system calls
      storageTotal: 0, // Requires additional system calls
      storageAvailable: 0, // Requires additional system calls
      isPhysicalDevice: iosInfo.isPhysicalDevice,
      manufacturer: 'Apple',
      additionalDetails: {
        'name': iosInfo.name,
        'system_name': iosInfo.systemName,
      },
    );
  }

  Future<DeviceDetails> _getWindowsDeviceInfo() async {
    final windowsInfo = await _deviceInfo.windowsInfo;
    return DeviceDetails(
      deviceId: windowsInfo.deviceId,
      model: windowsInfo.computerName,
      osVersion: windowsInfo.osVersion,
      deviceType: DeviceType.desktop,
      totalMemory: 0, // Requires additional system calls
      availableMemory: 0, // Requires additional system calls
      storageTotal: 0, // Requires additional system calls
      storageAvailable: 0, // Requires additional system calls
      isPhysicalDevice: true,
      manufacturer: 'Microsoft',
      additionalDetails: {
        'computer_name': windowsInfo.computerName,
      },
    );
  }

  Future<DeviceDetails> _getMacOSDeviceInfo() async {
    final macOSInfo = await _deviceInfo.macOsInfo;
    return DeviceDetails(
      deviceId: macOSInfo.systemGUID ?? 'Unknown',
      model: macOSInfo.model,
      osVersion: macOSInfo.osVersion,
      deviceType: DeviceType.desktop,
      totalMemory: 0, // Requires additional system calls
      availableMemory: 0, // Requires additional system calls
      storageTotal: 0, // Requires additional system calls
      storageAvailable: 0, // Requires additional system calls
      isPhysicalDevice: true,
      manufacturer: 'Apple',
      additionalDetails: {
        'kernel_version': macOSInfo.kernelVersion,
      },
    );
  }

  Future<DeviceDetails> _getLinuxDeviceInfo() async {
    final linuxInfo = await _deviceInfo.linuxInfo;
    return DeviceDetails(
      deviceId: linuxInfo.machineId ?? 'Unknown',
      model: linuxInfo.version ?? 'Unknown',
      osVersion: linuxInfo.version ?? 'Unknown',
      deviceType: DeviceType.desktop,
      totalMemory: 0, // Requires additional system calls
      availableMemory: 0, // Requires additional system calls
      storageTotal: 0, // Requires additional system calls
      storageAvailable: 0, // Requires additional system calls
      isPhysicalDevice: true,
      manufacturer: 'Linux',
      additionalDetails: {
        'machine_id': linuxInfo.machineId,
        'id': linuxInfo.id,
      },
    );
  }

  DeviceDetails _getDefaultDeviceInfo() {
    return DeviceDetails(
      deviceId: 'Unknown',
      model: 'Unknown',
      osVersion: 'Unknown',
      deviceType: DeviceType.unknown,
      totalMemory: 0,
      availableMemory: 0,
      storageTotal: 0,
      storageAvailable: 0,
      isPhysicalDevice: false,
      manufacturer: 'Unknown',
    );
  }

  DeviceType _determineDeviceType(dynamic screenSize) {
    // This is a simplified implementation and might need refinement
    // You would typically use screen dimensions and pixel density
    if (screenSize == null) return DeviceType.unknown;
    
    // Example logic (you'd replace this with more sophisticated detection)
    return screenSize.width > 600 ? DeviceType.tablet : DeviceType.phone;
  }

  void dispose() {
    _deviceDetailsController.close();
  }
}