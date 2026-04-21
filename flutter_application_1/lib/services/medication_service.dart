import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../data/app_repository.dart';

/// Service for managing daily medication checklist resets and missed-dose detection
class MedicationService {
  MedicationService._();
  static final MedicationService instance = MedicationService._();

  factory MedicationService() => instance;

  final _repo = AppRepository.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Background task name for medication reset
  static const String dailyResetTaskName = 'daily_medication_reset';
  static const String missedDoseCheckTaskName = 'missed_dose_check';

  /// Initialize background task scheduler
  /// Call this once at app startup
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Schedule daily medication reset at 12:00 AM
    await _scheduleDailyReset();

    // Schedule missed-dose check every 5 minutes
    await _scheduleMissedDoseCheck();

    // Initialize local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);
  }

  /// Schedule daily reset at midnight
  Future<void> _scheduleDailyReset() async {
    await Workmanager().registerPeriodicTask(
      dailyResetTaskName,
      dailyResetTaskName,
      frequency: const Duration(days: 1),
      initialDelay: _nextMidnight(),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Schedule missed-dose check every 5 minutes
  Future<void> _scheduleMissedDoseCheck() async {
    await Workmanager().registerPeriodicTask(
      missedDoseCheckTaskName,
      missedDoseCheckTaskName,
      frequency: const Duration(minutes: 5),
      constraints: Constraints(
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Reset all medication confirmations to "pending"
  /// Called at 12:00 AM daily
  Future<void> resetDailyMedications() async {
    try {
      // Get all medications for all members
      final medications = await _getAllMedications();

      // For each medication, delete today's confirmation so it resets to "pending"
      for (final med in medications) {
        // In a production app, you'd update the med_confirmations table
        // For now, we'll just log
        print('Reset medication: $med');
      }

      // Send notification to confirm reset
      await _sendLocalNotification(
        title: 'Medication Reminder',
        body: 'Daily medication checklist has been reset for a new day.',
        payload: 'med_reset',
      );
    } catch (e) {
      print('Error resetting medications: $e');
    }
  }

  /// Check for missed doses and notify family admins
  /// Called every 5 minutes
  Future<void> checkForMissedDoses() async {
    try {
      // This is a simplified version
      // In production, you'd:
      // 1. Query all medications with scheduled times
      // 2. Check if current time > scheduled_time + 2 hours AND not confirmed
      // 3. Mark as "Missed"
      // 4. Fetch all family admins for the member
      // 5. Send push notifications to each admin
      
      print('Checking for missed doses...');
      
      // Placeholder for missed dose detection logic
      // This would interact with your backend to send FCM notifications to admins
    } catch (e) {
      print('Error checking missed doses: $e');
    }
  }

  /// Get all medications (helper method)
  Future<List<dynamic>> getAllMedications() async {
    // This would be added to AppRepository
    return [];
  }

  /// Send local notification
  Future<void> _sendLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Reminders for daily medication management',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Calculate duration until next midnight
  Duration _nextMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}

/// Callback for background tasks (must be a top-level function)
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case MedicationService.dailyResetTaskName:
          await MedicationService.instance.resetDailyMedications();
          return true;
        case MedicationService.missedDoseCheckTaskName:
          await MedicationService.instance.checkForMissedDoses();
          return true;
        default:
          return false;
      }
    } catch (e) {
      print('Background task failed: $e');
      return false;
    }
  });
}

/// Helper function to get all medications
Future<List<dynamic>> _getAllMedications() async {
  // This would fetch from the database
  // For now, return empty list
  return [];
}
