import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingControls extends StatefulWidget {
  @override
  _RecordingControlsState createState() => _RecordingControlsState();
}

class _RecordingControlsState extends State<RecordingControls> {
  bool _isRecording = false;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final screenRecordStatus = await Permission.storage.status;
    final microphoneStatus = await Permission.microphone.status;

    setState(() {
      _hasPermissions = screenRecordStatus.isGranted && microphoneStatus.isGranted;
    });

    if (!_hasPermissions) {
      await _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    final screenRecordStatus = await Permission.storage.request();
    final microphoneStatus = await Permission.microphone.request();

    setState(() {
      _hasPermissions = screenRecordStatus.isGranted && microphoneStatus.isGranted;
    });
  }

  void _toggleRecording() {
    if (!_hasPermissions) {
      _checkPermissions();
      return;
    }

    setState(() {
      _isRecording = !_isRecording;
      // TODO: Implement actual screen and audio recording logic
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: _isRecording ? Colors.red : Colors.black,
              size: 50,
            ),
            onPressed: _toggleRecording,
          ),
          if (!_hasPermissions)
            Text(
              'Permissions required',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}