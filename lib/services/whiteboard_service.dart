import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'storage_service.dart';
import 'cloud_sync_service.dart';
import 'logging_service.dart';
import 'analytics_service.dart';
import 'performance_service.dart';

enum DrawingTool {
  pen,
  highlighter,
  eraser,
  line,
  rectangle,
  circle,
  arrow
}

enum WhiteboardMode {
  draw,
  erase,
  select
}

class DrawingStroke {
  final String id;
  final DrawingTool tool;
  final Color color;
  final double strokeWidth;
  final List<Offset> points;
  final DateTime timestamp;

  DrawingStroke({
    String? id,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.points,
    DateTime? timestamp,
  })  : id = id ?? Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool.toString(),
    'color': color.value,
    'strokeWidth': strokeWidth,
    'points': points.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
    'timestamp': timestamp.toIso8601String(),
  };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
    id: json['id'],
    tool: DrawingTool.values.firstWhere((e) => e.toString() == json['tool']),
    color: Color(json['color']),
    strokeWidth: json['strokeWidth'],
    points: (json['points'] as List)
      .map((p) => Offset(p['dx'], p['dy']))
      .toList(),
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class WhiteboardState {
  final String id;
  final List<DrawingStroke> strokes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WhiteboardState({
    String? id,
    this.strokes = const [],
    DateTime? createdAt,
    this.updatedAt,
  })  : id = id ?? Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  WhiteboardState copyWith({
    List<DrawingStroke>? strokes,
    DateTime? updatedAt,
  }) => WhiteboardState(
    id: id,
    strokes: strokes ?? this.strokes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory WhiteboardState.fromJson(Map<String, dynamic> json) => WhiteboardState(
    id: json['id'],
    strokes: (json['strokes'] as List)
      .map((s) => DrawingStroke.fromJson(s))
      .toList(),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: json['updatedAt'] != null 
      ? DateTime.parse(json['updatedAt'])
      : null,
  );
}

class WhiteboardService {
  static final WhiteboardService _instance = WhiteboardService._internal();
  factory WhiteboardService() => _instance;
  WhiteboardService._internal();

  final StorageService _storageService = StorageService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final PerformanceService _performanceService = PerformanceService();

  final _stateController = StreamController<WhiteboardState>.broadcast();
  final _undoStackController = StreamController<List<WhiteboardState>>.broadcast();
  final _redoStackController = StreamController<List<WhiteboardState>>.broadcast();

  Stream<WhiteboardState> get stateStream => _stateController.stream;
  Stream<List<WhiteboardState>> get undoStackStream => _undoStackController.stream;
  Stream<List<WhiteboardState>> get redoStackStream => _redoStackController.stream;

  WhiteboardState _currentState = WhiteboardState();
  List<WhiteboardState> _undoStack = [];
  List<WhiteboardState> _redoStack = [];

  DrawingTool _currentTool = DrawingTool.pen;
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 2.0;

  void setTool(DrawingTool tool) {
    _currentTool = tool;
    _analyticsService.logEvent(
      name: 'whiteboard_tool_changed',
      parameters: {'tool': tool.toString()},
      category: AnalyticsEventCategory.userInteraction,
    );
  }

  void setColor(Color color) {
    _currentColor = color;
    _analyticsService.logEvent(
      name: 'whiteboard_color_changed',
      parameters: {'color': color.value},
      category: AnalyticsEventCategory.userInteraction,
    );
  }

  void setStrokeWidth(double width) {
    _currentStrokeWidth = width;
    _analyticsService.logEvent(
      name: 'whiteboard_stroke_width_changed',
      parameters: {'width': width},
      category: AnalyticsEventCategory.userInteraction,
    );
  }

  void addStroke(List<Offset> points) {
    final stroke = DrawingStroke(
      tool: _currentTool,
      color: _currentColor,
      strokeWidth: _currentStrokeWidth,
      points: points,
    );

    _pushToUndoStack();
    _currentState = _currentState.copyWith(
      strokes: [..._currentState.strokes, stroke],
    );
    _stateController.add(_currentState);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_currentState);
      _currentState = _undoStack.removeLast();
      _stateController.add(_currentState);
      
      _analyticsService.logEvent(
        name: 'whiteboard_undo',
        category: AnalyticsEventCategory.userInteraction,
      );
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _pushToUndoStack();
      _currentState = _redoStack.removeLast();
      _stateController.add(_currentState);
      
      _analyticsService.logEvent(
        name: 'whiteboard_redo',
        category: AnalyticsEventCategory.userInteraction,
      );
    }
  }

  void _pushToUndoStack() {
    _undoStack.add(_currentState);
    _undoStackController.add(_undoStack);
  }

  Future<void> saveWhiteboard() async {
    try {
      final jsonState = json.encode(_currentState.toJson());
      final file = await _storageService.saveFile(
        file: File.fromRawPath(utf8.encode(jsonState)),
        location: StorageLocation.documents,
        customName: 'whiteboard_${DateTime.now().toIso8601String()}.json',
      );

      await _cloudSyncService.uploadRecording(file);

      _analyticsService.logEvent(
        name: 'whiteboard_saved',
        parameters: {
          'strokes_count': _currentState.strokes.length,
        },
        category: AnalyticsEventCategory.fileManagement,
      );
    } catch (e) {
      _loggingService.error('Whiteboard save failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> loadWhiteboard(String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final loadedState = WhiteboardState.fromJson(json.decode(jsonString));

      _pushToUndoStack();
      _currentState = loadedState;
      _stateController.add(_currentState);

      _analyticsService.logEvent(
        name: 'whiteboard_loaded',
        parameters: {
          'strokes_count': _currentState.strokes.length,
        },
        category: AnalyticsEventCategory.fileManagement,
      );
    } catch (e) {
      _loggingService.error('Whiteboard load failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  void clearWhiteboard() {
    _pushToUndoStack();
    _currentState = WhiteboardState();
    _stateController.add(_currentState);
    _redoStack.clear();

    _analyticsService.logEvent(
      name: 'whiteboard_cleared',
      category: AnalyticsEventCategory.userInteraction,
    );
  }

  void dispose() {
    _stateController.close();
    _undoStackController.close();
    _redoStackController.close();
  }
}