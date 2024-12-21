import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/recording_manager.dart';
import '../utils/constants.dart';

class RecordingsScreen extends StatefulWidget {
  @override
  _RecordingsScreenState createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<String> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recordings = await RecordingManager.getAllRecordings();
      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load recordings');
    }
  }

  Future<void> _deleteRecording(String filePath) async {
    try {
      await RecordingManager.deleteRecording(filePath);
      await _loadRecordings();
    } catch (e) {
      _showErrorSnackBar('Failed to delete recording');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getRecordingName(String filePath) {
    final fileName = filePath.split('/').last;
    return fileName.replaceAll('.mp4', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Recordings'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? _buildEmptyState()
              : _buildRecordingsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_collection_outlined,
            size: 100,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No recordings yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRecordings,
            child: Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return ListView.builder(
      itemCount: _recordings.length,
      itemBuilder: (context, index) {
        final recording = _recordings[index];
        return Dismissible(
          key: Key(recording),
          background: Container(
            color: Colors.red,
            child: Icon(
              Icons.delete,
              color: Colors.white,
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 16),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deleteRecording(recording),
          child: ListTile(
            title: Text(_getRecordingName(recording)),
            subtitle: Text(_formatFileSize(recording)),
            trailing: IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                // TODO: Implement video playback
              },
            ),
            onTap: () {
              // TODO: Implement video playback
            },
          ),
        );
      },
    );
  }

  String _formatFileSize(String filePath) {
    final file = File(filePath);
    final bytes = file.lengthSync();
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}