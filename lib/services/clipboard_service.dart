import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

enum ClipboardContentType {
  text,
  image,
  recording,
  unknown
}

class ClipboardContent {
  final ClipboardContentType type;
  final dynamic data;
  final DateTime timestamp;

  ClipboardContent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Clipboard history
  final List<ClipboardContent> _clipboardHistory = [];
  static const int _maxHistorySize = 10;

  Future<void> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      
      _addToClipboardHistory(ClipboardContent(
        type: ClipboardContentType.text,
        data: text,
      ));

      _analyticsService.logEvent(
        name: 'clipboard_copy',
        parameters: {
          'type': 'text',
          'length': text.length,
        },
      );

      _loggingService.info('Text copied to clipboard');
    } catch (e) {
      _loggingService.error('Failed to copy text to clipboard', error: e);
    }
  }

  Future<String?> pasteText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      
      if (data != null && data.text != null) {
        _analyticsService.logEvent(
          name: 'clipboard_paste',
          parameters: {
            'type': 'text',
            'length': data.text!.length,
          },
        );

        _loggingService.info('Text pasted from clipboard');
        return data.text;
      }
      return null;
    } catch (e) {
      _loggingService.error('Failed to paste text from clipboard', error: e);
      return null;
    }
  }

  Future<void> copyImage(Uint8List imageData) async {
    try {
      // For web and mobile platforms
      if (kIsWeb) {
        // Web-specific clipboard image handling
        await Clipboard.setData(ClipboardData(text: 'Image copied'));
      } else {
        // Platform-specific image clipboard methods would go here
        // This is a placeholder and would require platform-specific implementation
      }

      _addToClipboardHistory(ClipboardContent(
        type: ClipboardContentType.image,
        data: imageData,
      ));

      _analyticsService.logEvent(
        name: 'clipboard_copy',
        parameters: {
          'type': 'image',
          'size': imageData.length,
        },
      );

      _loggingService.info('Image copied to clipboard');
    } catch (e) {
      _loggingService.error('Failed to copy image to clipboard', error: e);
    }
  }

  Future<void> copyRecording(String recordingPath) async {
    try {
      // For web and mobile platforms
      if (kIsWeb) {
        // Web-specific recording clipboard handling
        await Clipboard.setData(ClipboardData(text: recordingPath));
      } else {
        // Platform-specific recording clipboard methods would go here
        // This is a placeholder and would require platform-specific implementation
      }

      _addToClipboardHistory(ClipboardContent(
        type: ClipboardContentType.recording,
        data: recordingPath,
      ));

      _analyticsService.logEvent(
        name: 'clipboard_copy',
        parameters: {
          'type': 'recording',
        },
      );

      _loggingService.info('Recording path copied to clipboard');
    } catch (e) {
      _loggingService.error('Failed to copy recording to clipboard', error: e);
    }
  }

  void _addToClipboardHistory(ClipboardContent content) {
    _clipboardHistory.insert(0, content);
    
    // Maintain max history size
    if (_clipboardHistory.length > _maxHistorySize) {
      _clipboardHistory.removeRange(
        _maxHistorySize, 
        _clipboardHistory.length
      );
    }
  }

  List<ClipboardContent> getClipboardHistory() {
    return List.unmodifiable(_clipboardHistory);
  }

  Future<void> clearClipboardHistory() async {
    _clipboardHistory.clear();
    
    _analyticsService.logEvent(name: 'clipboard_history_cleared');
    _loggingService.info('Clipboard history cleared');
  }

  Future<bool> hasClipboardContent() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text != null && data!.text!.isNotEmpty;
    } catch (e) {
      _loggingService.error('Failed to check clipboard content', error: e);
      return false;
    }
  }

  void dispose() {
    // Cleanup if needed
  }
}