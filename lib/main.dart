import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Service Imports
import 'services/auth_service.dart';
import 'services/logging_service.dart';
import 'services/analytics_service.dart';
import 'services/performance_service.dart';
import 'services/connectivity_service.dart';
import 'services/device_info_service.dart';
import 'services/localization_service.dart';

// UI Imports
import 'ui/theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';

class TeacherWhiteboardApp extends StatefulWidget {
  const TeacherWhiteboardApp({Key? key}) : super(key: key);

  @override
  _TeacherWhiteboardAppState createState() => _TeacherWhiteboardAppState();
}

class _TeacherWhiteboardAppState extends State<TeacherWhiteboardApp> {
  final _authService = AuthService();
  final _loggingService = LoggingService();
  final _analyticsService = AnalyticsService();
  final _performanceService = PerformanceService();
  final _connectivityService = ConnectivityService();
  final _deviceInfoService = DeviceInfoService();
  final _localizationService = LocalizationService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize services in a specific order
      await _loggingService.init();
      await _analyticsService.init();
      await _authService.init();
      await _performanceService.init();
      await _connectivityService.init();
      await _deviceInfoService.init();
      await _localizationService.init();

      // Track app startup performance
      await _performanceService.trackStartupPerformance(() async {
        // Any additional startup logic can go here
      });

      _loggingService.info('All services initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.critical(
        'Service initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
      _analyticsService.recordError(e, stackTrace);
    }
  }

  @override
  void dispose() {
    // Dispose of all services
    _authService.dispose();
    _loggingService.dispose();
    _analyticsService.dispose();
    _performanceService.dispose();
    _connectivityService.dispose();
    _deviceInfoService.dispose();
    _localizationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Enforce portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return StreamBuilder<Locale>(
      stream: _localizationService.localeStream.map((appLocale) => appLocale.locale),
      initialData: _localizationService.currentLocale.locale,
      builder: (context, localeSnapshot) {
        return MaterialApp(
          title: 'Teacher Whiteboard',
          debugShowCheckedModeBanner: false,
          
          // Theming
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,

          // Localization
          locale: localeSnapshot.data,
          supportedLocales: _localizationService.supportedLocalesList,
          localizationsDelegates: _localizationService.localizationDelegates,

          // Navigation
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/dashboard': (context) => const DashboardScreen(),
          },

          // Error Handling
          builder: (context, child) {
            return StreamBuilder<NetworkQualityInfo>(
              stream: _connectivityService.networkStatusStream,
              builder: (context, connectivitySnapshot) {
                if (!connectivitySnapshot.hasData || 
                    connectivitySnapshot.data?.isConnected == false) {
                  return _buildOfflineWidget(context);
                }
                return child ?? Container();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineWidget(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'No Internet Connection',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Please check your network settings',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeacherWhiteboardApp());
}