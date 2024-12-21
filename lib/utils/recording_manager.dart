import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class RecordingManager {
  static Future<String> saveRecording({
    required File videoFile,
    required File audioFile,
  }) async {
    try {
      // Generate a unique filename
      final uuid = Uuid();
      final timestamp = DateTime.now().toIso8601String();
      final recordingId = uuid.v4();

      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      // Create recordings directory if it doesn't exist
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Create unique filenames
      final videoFileName = '$recordingId-$timestamp.mp4';
      final audioFileName = '$recordingId-$timestamp.m4a';

      // Save files
      final savedVideoFile = await videoFile.copy('${recordingsDir.path}/$videoFileName');
      final savedAudioFile = await audioFile.copy('${recordingsDir.path}/$audioFileName');

      return recordingId;
    } catch (e) {
      print('Error saving recording: $e');
      rethrow;
    }
  }

  static Future<List<String>> getAllRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      if (!await recordingsDir.exists()) {
        return [];
      }

      final recordings = recordingsDir
          .listSync()
          .where((file) => file.path.endsWith('.mp4'))
          .map((file) => file.path)
          .toList();

      return recordings;
    } catch (e) {
      print('Error retrieving recordings: $e');
      return [];
    }
  }

  static Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        
        // Also delete corresponding audio file
        final audioFilePath = filePath.replaceAll('.mp4', '.m4a');
        final audioFile = File(audioFilePath);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }
    } catch (e) {
      print('Error deleting recording: $e');
    }
  }
}