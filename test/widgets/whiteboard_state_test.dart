import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:teacher_whiteboard/widgets/whiteboard_canvas.dart';
import 'package:teacher_whiteboard/providers/whiteboard_state.dart';

void main() {
  group('WhiteboardCanvas', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
      // Create a WhiteboardState
      final whiteboardState = WhiteboardState();

      // Build our app and trigger a frame
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: whiteboardState,
          child: MaterialApp(
            home: Scaffold(
              body: WhiteboardCanvas(),
            ),
          ),
        ),
      );

      // Verify that the WhiteboardCanvas is rendered
      expect(find.byType(WhiteboardCanvas), findsOneWidget);
    });

    testWidgets('can draw points', (WidgetTester tester) async {
      final whiteboardState = WhiteboardState();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: whiteboardState,
          child: MaterialApp(
            home: Scaffold(
              body: WhiteboardCanvas(),
            ),
          ),
        ),
      );

      // Simulate a pan gesture
      await tester.dragFrom(
        tester.getCenter(find.byType(WhiteboardCanvas)),
        const Offset(100, 100),
      );

      // Verify that points have been added
      expect(whiteboardState.points.isNotEmpty, isTrue);
    });
  });
}