import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../data/app_repository.dart';

/// Alert severity levels
enum AlertLevel { normal, warning, danger }

/// Service for checking vital signs against danger thresholds
/// Triggers alerts when readings exceed safe limits
class VitalAlertService {
  VitalAlertService._();
  static final VitalAlertService instance = VitalAlertService._();

  factory VitalAlertService() => instance;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize notification service
  Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    // Request notification permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
  }

  /// Check a vital reading against thresholds
  /// Returns alert level and should trigger notification
  Future<(AlertLevel, bool)> checkVitalReading({
    required String memberId,
    required String vitalType,
    required double readingValue,
    required String memberName,
  }) async {
    try {
      // Get stored thresholds for this member
      final threshold =
          await AppRepository.instance.getVitalThreshold(memberId, vitalType);

      if (threshold == null) {
        // No threshold configured - treat as normal
        return (AlertLevel.normal, false);
      }

      final dangerMin = threshold['danger_min'] as double?;
      final dangerMax = threshold['danger_max'] as double?;
      final warningMin = threshold['warning_min'] as double?;
      final warningMax = threshold['warning_max'] as double?;

      // Check danger zone first
      if ((dangerMin != null && readingValue < dangerMin) ||
          (dangerMax != null && readingValue > dangerMax)) {
        return (AlertLevel.danger, true);
      }

      // Check warning zone
      if ((warningMin != null && readingValue < warningMin) ||
          (warningMax != null && readingValue > warningMax)) {
        return (AlertLevel.warning, true);
      }

      return (AlertLevel.normal, false);
    } catch (e) {
      print('Error checking vital threshold: $e');
      return (AlertLevel.normal, false);
    }
  }

  /// Show verification dialog before sending danger alert
  /// (This should be called from UI context)
  /// Returns true if user confirms the reading is correct
  static Future<bool> showVerificationDialog(
    BuildContext context, {
    required String vitalType,
    required double readingValue,
    required String unit,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFFFEBEE),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.warning_rounded, color: Color(0xFFD32F2F), size: 40),
        ),
        title: const Text(
          'Critical Reading Alert',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You entered $readingValue $unit for $vitalType.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a CRITICAL level. Is this reading correct?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFF57C00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No, let me re-enter',
              style: TextStyle(color: Color(0xFF757575)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              minimumSize: const Size(120, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, confirm',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  /// Send danger alert notification to member and family admins
  Future<void> sendDangerAlert({
    required String memberId,
    required String memberName,
    required String vitalType,
    required double readingValue,
    required String unit,
    required List<String> adminTokens,
  }) async {
    try {
      final timestamp = DateTime.now();
      final readableTime =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

      // Local notification for member
      await _sendLocalNotification(
        title: '⚠️ CRITICAL VITAL ALERT',
        body: 'Your $vitalType reading ($readingValue $unit) is critically high!',
        payload: 'vital_alert_$memberId',
      );

      // Push notifications to family admins
      for (final token in adminTokens) {
        await _sendPushNotification(
          token: token,
          title: '🚨 Family Alert: $memberName',
          body: '$vitalType = $readingValue $unit (Critical)',
          data: {
            'type': 'vital_alert',
            'member_id': memberId,
            'member_name': memberName,
            'vital_type': vitalType,
            'reading': readingValue.toString(),
            'unit': unit,
            'time': readableTime,
          },
        );
      }
    } catch (e) {
      print('Error sending vital alert: $e');
    }
  }

  /// Send warning alert notification
  Future<void> sendWarningAlert({
    required String memberId,
    required String memberName,
    required String vitalType,
    required double readingValue,
    required String unit,
  }) async {
    try {
      await _sendLocalNotification(
        title: '⚠️ Vital Warning',
        body: 'Your $vitalType reading ($readingValue $unit) is in the warning zone.',
        payload: 'vital_warning_$memberId',
      );
    } catch (e) {
      print('Error sending warning alert: $e');
    }
  }

  /// Send local notification
  Future<void> _sendLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'vital_alerts',
      'Vital Sign Alerts',
      channelDescription: 'Notifications for critical vital sign readings',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
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

  /// Send push notification via Firebase Cloud Messaging
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    // This would typically call your backend to send via FCM
    // For now, we'll just send a local notification as a demo
    await _sendLocalNotification(
      title: title,
      body: body,
      payload: data['member_id'] ?? '',
    );
  }

  /// Get display color for alert level
  static String getAlertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.normal:
        return '🟢'; // Green
      case AlertLevel.warning:
        return '🟡'; // Yellow
      case AlertLevel.danger:
        return '🔴'; // Red
      default:
        return '⚪'; // Gray
    }
  }

  /// Get alert message
  static String getAlertMessage(AlertLevel level) {
    switch (level) {
      case AlertLevel.normal:
        return 'Normal';
      case AlertLevel.warning:
        return 'Warning';
      case AlertLevel.danger:
        return 'CRITICAL';
      default:
        return 'Unknown';
    }
  }
}
