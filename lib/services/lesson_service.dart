import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'recording_service.dart';
import 'whiteboard_service.dart';
import 'storage_service.dart';
import 'cloud_sync_service.dart';
import 'auth_service.dart';
import 'logging_service.dart';
import 'analytics_service.dart';
import 'performance_service.dart';

enum LessonStatus {
  draft,
  inProgress,
  completed,
  archived
}

enum LessonCategory {
  mathematics,
  science,
  literature,
  history,
  language,
  other
}

class LessonResource {
  final String id;
  final String path;
  final String type; // 'recording', 'whiteboard', 'attachment'
  final DateTime createdAt;

  LessonResource({
    String? id,
    required this.path,
    required this.type,
    DateTime? createdAt,
  })  : id = id ?? Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'type': type,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LessonResource.fromJson(Map<String, dynamic> json) => LessonResource(
    id: json['id'],
    path: json['path'],
    type: json['type'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class LessonMetadata {
  final String id;
  final String title;
  final String? description;
  final LessonStatus status;
  final LessonCategory category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final List<LessonResource> resources;
  final String? authorId;

  LessonMetadata({
    String? id,
    required this.title,
    this.description,
    this.status = LessonStatus.draft,
    this.category = LessonCategory.other,
    List<String>? tags,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    List<LessonResource>? resources,
    this.authorId,
  })  : id = id ?? Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        tags = tags ?? [],
        resources = resources ?? [];

  LessonMetadata copyWith({
    String? title,
    String? description,
    LessonStatus? status,
    LessonCategory? category,
    List<String>? tags,
    DateTime? updatedAt,
    DateTime? completedAt,
    List<LessonResource>? resources,
  }) => LessonMetadata(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    completedAt: completedAt,
    resources: resources ?? this.resources,
    authorId: authorId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.toString(),
    'category': category.toString(),
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'resources': resources.map((r) => r.toJson()).toList(),
    'authorId': authorId,
  };

  factory LessonMetadata.fromJson(Map<String, dynamic> json) => LessonMetadata(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    status: LessonStatus.values.firstWhere((e) => e.toString() == json['status']),
    category: LessonCategory.values.firstWhere((e) => e.toString() == json['category']),
    tags: List<String>.from(json['tags']),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    resources: (json['resources'] as List)
      .map((r) => LessonResource.fromJson(r))
      .toList(),
    authorId: json['authorId'],
  );
}

class LessonService {
  static final LessonService _instance = LessonService._internal();
  factory LessonService() => _instance;
  LessonService._internal();

  final StorageService _storageService = StorageService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  final RecordingService _recordingService = RecordingService();
  final WhiteboardService _whiteboardService = WhiteboardService();
  final AuthService _authService = AuthService();
  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final PerformanceService _performanceService = PerformanceService();

  final _lessonsController = StreamController<List<LessonMetadata>>.broadcast();
  final _currentLessonController = StreamController<LessonMetadata?>.broadcast();

  Stream<List<LessonMetadata>> get lessonsStream => _lessonsController.stream;
  Stream<LessonMetadata?> get currentLessonStream => _currentLessonController.stream;

  List<LessonMetadata> _lessons = [];
  LessonMetadata? _currentLesson;

  Future<void> createLesson({
    required String title,
    String? description,
    LessonCategory category = LessonCategory.other,
    List<String>? tags,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final lesson = LessonMetadata(
        title: title,
        description: description,
        category: category,
        tags: tags,
        authorId: user.uid,
      );

      _lessons.add(lesson);
      _currentLesson = lesson;
      
      _lessonsController.add(_lessons);
      _currentLessonController.add(_currentLesson);

      _analyticsService.logEvent(
        name: 'lesson_created',
        parameters: {
          'category': category.toString(),
          'tags_count': tags?.length ?? 0,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Lesson created: $title');

      // Automatically start recording and whiteboard
      await _recordingService.startRecording();
      
    } catch (e) {
      _loggingService.error('Failed to create lesson', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> updateLesson({
    String? title,
    String? description,
    LessonStatus? status,
    LessonCategory? category,
    List<String>? tags,
  }) async {
    try {
      if (_currentLesson == null) {
        throw Exception('No active lesson');
      }

      _currentLesson = _currentLesson!.copyWith(
        title: title,
        description: description,
        status: status,
        category: category,
        tags: tags,
      );

      final index = _lessons.indexWhere((l) => l.id == _currentLesson!.id);
      if (index != -1) {
        _lessons[index] = _currentLesson!;
      }

      _lessonsController.add(_lessons);
      _currentLessonController.add(_currentLesson);

      _analyticsService.logEvent(
        name: 'lesson_updated',
        parameters: {
          'status': status?.toString(),
          'category': category?.toString(),
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Lesson updated: ${_currentLesson!.title}');
    } catch (e) {
      _loggingService.error('Failed to update lesson', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> completeLesson() async {
    try {
      if (_currentLesson == null) {
        throw Exception('No active lesson');
      }

      // Stop recording
      final recordingMetadata = await _recordingService.stopRecording();
      
      // Save whiteboard
      await _whiteboardService.saveWhiteboard();

      // Add resources to lesson
      final resources = <LessonResource>[];
      
      if (recordingMetadata != null) {
        resources.add(LessonResource(
          path: recordingMetadata.filePath,
          type: 'recording',
        ));
      }

      _currentLesson = _currentLesson!.copyWith(
        status: LessonStatus.completed,
        completedAt: DateTime.now(),
        resources: resources,
      );

      final index = _lessons.indexWhere((l) => l.id == _currentLesson!.id);
      if (index != -1) {
        _lessons[index] = _currentLesson!;
      }

      _lessonsController.add(_lessons);
      _currentLessonController.add(_currentLesson);

      _analyticsService.logEvent(
        name: 'lesson_completed',
        parameters: {
          'resources_count': resources.length,
        },
        category: AnalyticsEventCategory.userInteraction,
      );

      _loggingService.info('Lesson completed: ${_currentLesson!.title}');

      // Cloud sync lesson metadata
      await _saveToCloud(_currentLesson!);
    } catch (e) {
      _loggingService.error('Failed to complete lesson', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<void> _saveToCloud(LessonMetadata lesson) async {
    try {
      final jsonLesson = json.encode(lesson.toJson());
      final file = await _storageService.saveFile(
        file: File.fromRawPath(utf8.encode(jsonLesson)),
        location: StorageLocation.documents,
        customName: 'lesson_${lesson.id}.json',
      );

      await _cloudSyncService.uploadRecording(file);
    } catch (e) {
      _loggingService.error('Failed to save lesson to cloud', error: e);
    }
  }

  Future<List<LessonMetadata>> searchLessons({
    String? query,
    LessonStatus? status,
    LessonCategory? category,
    List<String>? tags,
  }) async {
    try {
      return _lessons.where((lesson) {
        bool matches = true;

        if (query != null) {
          matches = matches && (
            lesson.title.toLowerCase().contains(query.toLowerCase()) ||
            (lesson.description?.toLowerCase().contains(query.toLowerCase()) ?? false)
          );
        }

        if (status != null) {
          matches = matches && lesson.status == status;
        }

        if (category != null) {
          matches = matches && lesson.category == category;
        }

        if (tags != null && tags.isNotEmpty) {
          matches = matches && tags.every((tag) => lesson.tags.contains(tag));
        }

        return matches;
      }).toList();
    } catch (e) {
      _loggingService.error('Lesson search failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      return [];
    }
  }

  void dispose() {
    _lessonsController.close();
    _currentLessonController.close();
  }
}