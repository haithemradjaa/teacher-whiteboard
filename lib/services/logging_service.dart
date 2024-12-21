import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical
}

class LogEntry {
  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.level,
    required this.message,
    DateTime? timestamp,
    this.error,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedMessage => '[${timestamp.toIso8601String()}] '
      '[${level.toString().split('.').last.toUpperCase()}] $message';
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  LogLevel _currentLogLevel = LogLevel.info;
  final _logController = StreamController<LogEntry>.broadcast();
  File? _logFile;

  Stream<LogEntry> get logStream => _logController.stream;

  Future<void> init() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _initializeLogFile();
    }
  }

  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDirectory = Directory('${directory.path}/logs');
      
      if (!await logDirectory.exists()) {
        await logDirectory.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      _logFile = File('${logDirectory.path}/app_log_$timestamp.txt');
    } catch (e) {
      debugPrint('Failed to initialize log file: $e');
    }
  }

  void setLogLevel(LogLevel level) {
    _currentLogLevel = level;
  }

  void _log(LogEntry entry) {
    if (entry.level.index >= _currentLogLevel.index) {
      // Console logging
      _consoleLog(entry);
      
      // File logging
      _fileLog(entry);
      
      // Stream logging
      _logController.add(entry);
    }
  }

  void _consoleLog(LogEntry entry) {
    switch (entry.level) {
      case LogLevel.debug:
        debugPrint(entry.formattedMessage);
        break;
      case LogLevel.info:
        debugPrint('\x1B[32m${entry.formattedMessage}\x1B[0m'); // Green
        break;
      case LogLevel.warning:
        debugPrint('\x1B[33m${entry.formattedMessage}\x1B[0m'); // Yellow
        break;
      case LogLevel.error:
      case LogLevel.critical:
        debugPrint('\x1B[31m${entry.formattedMessage}\x1B[0m'); // Red
        if (entry.error != null) {
          debugPrint('Error: ${entry.error}');
        }
        if (entry.stackTrace != null) {
          debugPrint('Stack Trace: ${entry.stackTrace}');
        }
        break;
    }
  }

  void _fileLog(LogEntry entry) {
    try {
      if (_logFile != null) {
        _logFile?.writeAsStringSync(
          '${entry.formattedMessage}\n',
          mode: FileMode.append,
        );

        if (entry.error != null) {
          _logFile?.writeAsStringSync(
            'Error: ${entry.error}\n',
            mode: FileMode.append,
          );
        }

        if (entry.stackTrace != null) {
          _logFile?.writeAsStringSync(
            'Stack Trace: ${entry.stackTrace}\n',
            mode: FileMode.append,
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    _log(LogEntry(
      level: LogLevel.debug,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void info(String message, {dynamic error, StackTrace? stackTrace}) {
    _log(LogEntry(
      level: LogLevel.info,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    _log(LogEntry(
      level: LogLevel.warning,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _log(LogEntry(
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void critical(String message, {dynamic error, StackTrace? stackTrace}) {
    _log(LogEntry(
      level: LogLevel.critical,
      message: message,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  void dispose() {
    _logController.close();
  }
}