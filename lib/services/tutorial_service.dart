import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'logging_service.dart';
import 'analytics_service.dart';

enum TutorialStep {
  welcome,
  whiteboard,
  recording,
  cloudBackup,
  advancedFeatures,
  completed
}

class TutorialProgress {
  final TutorialStep currentStep;
  final bool isFirstLaunch;
  final DateTime? firstLaunchDate;
  final int completedSteps;

  TutorialProgress({
    required this.currentStep,
    required this.isFirstLaunch,
    this.firstLaunchDate,
    this.completedSteps = 0,
  });
}

class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  final LoggingService _loggingService = LoggingService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Preference keys
  static const String _firstLaunchKey = 'first_launch_date';
  static const String _currentStepKey = 'tutorial_current_step';
  static const String _completedStepsKey = 'tutorial_completed_steps';

  // Stream controller for tutorial progress
  final _tutorialProgressController = 
    StreamController<TutorialProgress>.broadcast();
  Stream<TutorialProgress> get tutorialProgressStream => 
    _tutorialProgressController.stream;

  Future<void> init() async {
    try {
      // Ensure tutorial progress is initialized
      await _initializeTutorialProgress();
    } catch (e) {
      _loggingService.error('Tutorial service initialization failed', error: e);
    }
  }

  Future<void> _initializeTutorialProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if it's the first launch
    final firstLaunchDateString = prefs.getString(_firstLaunchKey);
    final isFirstLaunch = firstLaunchDateString == null;

    if (isFirstLaunch) {
      // Set first launch date
      await prefs.setString(
        _firstLaunchKey, 
        DateTime.now().toIso8601String()
      );
      
      // Set initial tutorial step
      await prefs.setInt(_currentStepKey, TutorialStep.welcome.index);
      await prefs.setInt(_completedStepsKey, 0);

      _analyticsService.logEvent(name: 'first_app_launch');
    }

    // Emit current tutorial progress
    _emitTutorialProgress();
  }

  Future<TutorialProgress> getCurrentProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    final firstLaunchDateString = prefs.getString(_firstLaunchKey);
    final currentStepIndex = prefs.getInt(_currentStepKey) ?? 0;
    final completedSteps = prefs.getInt(_completedStepsKey) ?? 0;

    return TutorialProgress(
      currentStep: TutorialStep.values[currentStepIndex],
      isFirstLaunch: firstLaunchDateString == null,
      firstLaunchDate: firstLaunchDateString != null 
        ? DateTime.parse(firstLaunchDateString) 
        : null,
      completedSteps: completedSteps,
    );
  }

  Future<void> advanceToNextStep() async {
    final prefs = await SharedPreferences.getInstance();
    final currentProgress = await getCurrentProgress();

    // Determine next step
    final nextStepIndex = currentProgress.currentStep.index + 1;
    
    if (nextStepIndex < TutorialStep.values.length) {
      await prefs.setInt(_currentStepKey, nextStepIndex);
      await prefs.setInt(
        _completedStepsKey, 
        currentProgress.completedSteps + 1
      );

      _analyticsService.logEvent(
        name: 'tutorial_step_completed',
        parameters: {
          'step': currentProgress.currentStep.toString(),
          'next_step': TutorialStep.values[nextStepIndex].toString(),
        },
      );

      _emitTutorialProgress();
    }
  }

  Future<void> skipTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_currentStepKey, TutorialStep.completed.index);
    await prefs.setInt(_completedStepsKey, TutorialStep.values.length);

    _analyticsService.logEvent(name: 'tutorial_skipped');
    _emitTutorialProgress();
  }

  Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_firstLaunchKey);
    await prefs.remove(_currentStepKey);
    await prefs.remove(_completedStepsKey);

    _analyticsService.logEvent(name: 'tutorial_reset');
    
    // Reinitialize tutorial progress
    await _initializeTutorialProgress();
  }

  void _emitTutorialProgress() async {
    final progress = await getCurrentProgress();
    _tutorialProgressController.add(progress);
  }

  bool shouldShowTutorial(TutorialStep step) {
    // Logic to determine if a specific tutorial step should be shown
    return step.index <= TutorialStep.completed.index;
  }

  Future<void> markStepAsViewed(TutorialStep step) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ensure we don't go backwards
    final currentProgress = await getCurrentProgress();
    if (step.index > currentProgress.currentStep.index) {
      await prefs.setInt(_currentStepKey, step.index);
      
      _analyticsService.logEvent(
        name: 'tutorial_step_viewed',
        parameters: {'step': step.toString()},
      );

      _emitTutorialProgress();
    }
  }

  void dispose() {
    _tutorialProgressController.close();
  }
}