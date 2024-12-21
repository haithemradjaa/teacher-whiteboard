import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

enum StorageLocation {
  recordings,
  thumbnails,
  cache,
  documents
}

class StorageFile {
  final String id;
  final String name;
  final String path;
  final int sizeInBytes;
  final DateTime createdAt;
  final DateTime lastModified;
  final StorageLocation location;

  StorageFile({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeInBytes,
    required this.createdAt,
    required this.lastModified,
    required this.location,
  });
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final Uuid _uuid = Uuid();

  // Storage directory cache
  Map<StorageLocation, Directory?> _storageDirectories = {};

  Future<void> init() async {
    try {
      // Preload storage directories
      await getRecordingsDirectory();
      await getThumbnailsDirectory();
      await getCacheDirectory();
      await getDocumentsDirectory();

      _loggingService.info('Storage service initialized');
    } catch (e) {
      _loggingService.error('Storage service initialization failed', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<Directory> getRecordingsDirectory() async {
    if (_storageDirectories[StorageLocation.recordings] != null) {
      return _storageDirectories[StorageLocation.recordings]!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDocDir.path}/recordings');
    
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    _storageDirectories[StorageLocation.recordings] = recordingsDir;
    return recordingsDir;
  }

  Future<Directory> getThumbnailsDirectory() async {
    if (_storageDirectories[StorageLocation.thumbnails] != null) {
      return _storageDirectories[StorageLocation.thumbnails]!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir = Directory('${appDocDir.path}/thumbnails');
    
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }

    _storageDirectories[StorageLocation.thumbnails] = thumbnailsDir;
    return thumbnailsDir;
  }

  Future<Directory> getCacheDirectory() async {
    if (_storageDirectories[StorageLocation.cache] != null) {
      return _storageDirectories[StorageLocation.cache]!;
    }

    final cacheDir = await getTemporaryDirectory();
    _storageDirectories[StorageLocation.cache] = cacheDir;
    return cacheDir;
  }

  Future<Directory> getDocumentsDirectory() async {
    if (_storageDirectories[StorageLocation.documents] != null) {
      return _storageDirectories[StorageLocation.documents]!;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    _storageDirectories[StorageLocation.documents] = appDocDir;
    return appDocDir;
  }

  Future<StorageFile> saveFile({
    required File file, 
    required StorageLocation location,
    String? customName,
  }) async {
    try {
      Directory targetDirectory;
      switch (location) {
        case StorageLocation.recordings:
          targetDirectory = await getRecordingsDirectory();
          break;
        case StorageLocation.thumbnails:
          targetDirectory = await getThumbnailsDirectory();
          break;
        case StorageLocation.cache:
          targetDirectory = await getCacheDirectory();
          break;
        case StorageLocation.documents:
          targetDirectory = await getDocumentsDirectory();
          break;
      }

      final fileName = customName ?? _generateUniqueFileName(file.path);
      final newFilePath = '${targetDirectory.path}/$fileName';
      
      final savedFile = await file.copy(newFilePath);
      final fileStat = await savedFile.stat();

      final storageFile = StorageFile(
        id: _uuid.v4(),
        name: fileName,
        path: newFilePath,
        sizeInBytes: fileStat.size,
        createdAt: fileStat.changed,
        lastModified: fileStat.modified,
        location: location,
      );

      _analyticsService.logEvent(
        name: 'file_saved',
        parameters: {
          'location': location.toString(),
          'size': storageFile.sizeInBytes,
        },
      );

      _loggingService.info('File saved: ${storageFile.path}');

      return storageFile;
    } catch (e) {
      _loggingService.error('Failed to save file', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> deleteFile(StorageFile storageFile) async {
    try {
      final file = File(storageFile.path);
      
      if (await file.exists()) {
        await file.delete();
        
        _analyticsService.logEvent(
          name: 'file_deleted',
          parameters: {
            'location': storageFile.location.toString(),
            'size': storageFile.sizeInBytes,
          },
        );

        _loggingService.info('File deleted: ${storageFile.path}');
      }
    } catch (e) {
      _loggingService.error('Failed to delete file', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  Future<List<StorageFile>> listFiles(StorageLocation location) async {
    try {
      Directory targetDirectory;
      switch (location) {
        case StorageLocation.recordings:
          targetDirectory = await getRecordingsDirectory();
          break;
        case StorageLocation.thumbnails:
          targetDirectory = await getThumbnailsDirectory();
          break;
        case StorageLocation.cache:
          targetDirectory = await getCacheDirectory();
          break;
        case StorageLocation.documents:
          targetDirectory = await getDocumentsDirectory();
          break;
      }

      final files = await targetDirectory.list().where((file) => 
        file is File
      ).toList();

      final storageFiles = <StorageFile>[];
      for (var file in files) {
        final fileStat = await (file as File).stat();
        
        storageFiles.add(StorageFile(
          id: _uuid.v4(),
          name: file.path.split('/').last,
          path: file.path,
          sizeInBytes: fileStat.size,
          createdAt: fileStat.changed,
          lastModified: fileStat.modified,
          location: location,
        ));
      }

      return storageFiles;
    } catch (e) {
      _loggingService.error('Failed to list files', error: e);
      _analyticsService.recordError(e, StackTrace.current);
      return [];
    }
  }

  String _generateUniqueFileName(String originalPath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalPath.split('.').last;
    return 'file_${timestamp}_${_uuid.v4().substring(0, 8)}.$extension';
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      await cacheDir.list().forEach((file) async {
        if (file is File) {
          await file.delete();
        }
      });

      _loggingService.info('Cache cleared');
      _analyticsService.logEvent(name: 'cache_cleared');
    } catch (e) {
      _loggingService.error('Failed to clear cache', error: e);
      _analyticsService.recordError(e, StackTrace.current);
    }
  }

  void dispose() {
    // Clear directory cache
    _storageDirectories.clear();
  }
}