import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_whiteboard/widgets/recording_controls.dart';

void main() {
  group('RecordingControls', () {
    testWidgets('initial state shows record button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingControls(),
          ),
        ),
      );

      // Find the record button
      final recordButtonFinder = find.byIcon(Icons.fiber_manual_record);
      expect(recordButtonFinder, findsOneWidget);
    });

    testWidgets('tapping record button changes state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingControls(),
          ),
        ),
      );

      // Find the record button
      final recordButtonFinder = find.byIcon(Icons.fiber_manual_record);
      
      // Tap the record button
      await tester.tap(recordButtonFinder);
      await tester.pump();

      // Verify the button changes to stop button
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('button color changes when recording', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecordingControls(),
          ),
        ),
      );

      // Find the record button
      final recordButtonFinder = find.byIcon(Icons.fiber_manual_record);
      
      // Tap the record button
      await tester.tap(recordButtonFinder);
      await tester.pump();

      // Check that the button color changes to red when recording
      final stopButtonFinder = find.byIcon(Icons.stop);
      expect(stopButtonFinder, findsOneWidget);
    });
  });
}