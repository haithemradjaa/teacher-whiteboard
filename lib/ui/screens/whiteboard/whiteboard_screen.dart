import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/whiteboard_state.dart';
import '../widgets/whiteboard_canvas.dart';
import '../widgets/recording_controls.dart';

class WhiteboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Whiteboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              Provider.of<WhiteboardState>(context, listen: false).clearBoard();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: WhiteboardCanvas(),
          ),
          RecordingControls(),
        ],
      ),
    );
  }
}