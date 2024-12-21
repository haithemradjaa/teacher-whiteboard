import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkModeEnabled = false;
  double _maxRecordingDuration = AppConstants.maxRecordingDurationMinutes.toDouble();
  int _maxRecordingsSaved = AppConstants.maxRecordingsSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: Text('Dark Mode'),
            subtitle: Text('Switch between light and dark themes'),
            value: _darkModeEnabled,
            onChanged: (bool value) {
              setState(() {
                _darkModeEnabled = value;
                // TODO: Implement theme switching
              });
            },
          ),
          
          _buildSectionHeader('Recording'),
          ListTile(
            title: Text('Max Recording Duration'),
            subtitle: Text('${_maxRecordingDuration.round()} minutes'),
          ),
          Slider(
            value: _maxRecordingDuration,
            min: 30,
            max: 240,
            divisions: 7,
            label: '${_maxRecordingDuration.round()} minutes',
            onChanged: (double value) {
              setState(() {
                _maxRecordingDuration = value;
                // TODO: Save max recording duration
              });
            },
          ),
          
          ListTile(
            title: Text('Max Recordings Saved'),
            subtitle: Text('$_maxRecordingsSaved recordings'),
          ),
          Slider(
            value: _maxRecordingsSaved.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: '$_maxRecordingsSaved recordings',
            onChanged: (double value) {
              setState(() {
                _maxRecordingsSaved = value.round();
                // TODO: Save max recordings limit
              });
            },
          ),
          
          _buildSectionHeader('Storage'),
          ListTile(
            title: Text('Clear All Recordings'),
            subtitle: Text('Permanently delete all saved recordings'),
            trailing: ElevatedButton(
              child: Text('Clear'),
              style: ElevatedButton.styleFrom(primary: Colors.red),
              onPressed: _showClearRecordingsDialog,
            ),
          ),
          
          _buildSectionHeader('About'),
          ListTile(
            title: Text('App Version'),
            subtitle: Text(AppConstants.appVersion),
          ),
          ListTile(
            title: Text('Privacy Policy'),
            onTap: () {
              // TODO: Implement privacy policy navigation
            },
          ),
          ListTile(
            title: Text('Terms of Service'),
            onTap: () {
              // TODO: Implement terms of service navigation
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  void _showClearRecordingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All Recordings'),
          content: Text('Are you sure you want to delete all recordings? This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Delete'),
              style: ElevatedButton.styleFrom(primary: Colors.red),
              onPressed: () {
                // TODO: Implement clear all recordings
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}