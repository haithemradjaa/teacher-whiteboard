import 'package:flutter/material.dart';
import '../screens/whiteboard_screen.dart';
import '../screens/recordings_screen.dart';
import '../screens/video_player_screen.dart';
import '../screens/settings_screen.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => WhiteboardScreen());
      
      case '/recordings':
        return MaterialPageRoute(builder: (_) => RecordingsScreen());
      
      case '/video_player':
        final args = settings.arguments as VideoPlayerScreenArguments;
        return MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoPath: args.videoPath,
          ),
        );
      
      case '/settings':
        return MaterialPageRoute(builder: (_) => SettingsScreen());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }

  static void navigateTo(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
  }

  static void navigateReplaceTo(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushReplacementNamed(routeName, arguments: arguments);
  }

  static void navigateAndRemoveUntil(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName, 
      (route) => false,
      arguments: arguments,
    );
  }

  static void goBack() {
    navigatorKey.currentState?.pop();
  }
}

// Arguments classes for routes that need specific data
class VideoPlayerScreenArguments {
  final String videoPath;

  VideoPlayerScreenArguments({required this.videoPath});
}