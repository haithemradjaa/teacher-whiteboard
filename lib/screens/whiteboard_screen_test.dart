import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:teacher_whiteboard/screens/whiteboard_screen.dart';
import 'package:teacher_whiteboard/providers/whiteboard_state.dart';
import 'package:teacher_whiteboard/widgets/whiteboard_canvas.dart';
import 'package:teacher_whiteboard/widgets/recording_controls.dart';

void main() {
  group('WhiteboardScreen', () {
    testWidgets('renders correctly with all components', (WidgetTester tester) async {
      // Create a WhiteboardState
      final whiteboardState = WhiteboardState();

      // Build our app and trigger a frame
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: whiteboardState,
          child: MaterialApp(
            home: WhiteboardScreen(),
          ),
        ),
      );

      // Verify AppBar
      expect(find.text('Teacher Whiteboard'), findsOneWidget);

      // Verify Clear button
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Verify WhiteboardCanvas
      expect(find.byType(WhiteboardCanvas), findsOneWidget);

      // Verify RecordingControls
      expect(find.byType(RecordingControls), findsOneWidget);
    });

    testWidgets('clear button works', (WidgetTester tester) async {
      // Create a WhiteboardState
      final whiteboardState = WhiteboardState();

      // Add some points to simulate drawing
      whiteboardState.addPoint(
        DrawingPoint(
          offset: const Offset(10, 10),
          paint: Paint()
            ..color = Colors.black
            ..strokeWidth = 2.0,
        ),
      );

      // Build our app and trigger a frame
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: whiteboardState,
          child: MaterialApp(
            home: WhiteboardScreen(),
          ),
        ),
      );

      // Find and tap the clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Verify that points have been cleared
      expect(whiteboardState.points.isEmpty, isTrue);
    });
  });
}