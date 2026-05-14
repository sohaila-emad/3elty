import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'remote_auth_service.dart';

/// Result returned after triggering SOS so the UI can show the right message.
class SosResult {
  final bool success;
  final String? errorMessage;
  final double? latitude;
  final double? longitude;
  final int notifiedCount;

  const SosResult({
    required this.success,
    this.errorMessage,
    this.latitude,
    this.longitude,
    this.notifiedCount = 0,
  });
}

/// Handles the full SOS flow:
///   1. Get GPS location
///   2. Write sos_alerts document to Firestore
///   3. Show a local notification on the sender's device
///
/// In-app banner for family members is handled via activeAlertsStream()
/// which listens to Firestore in real time in persistent_dashboard.dart
class SosService {
  SosService._();
  static final SosService instance = SosService._();
  factory SosService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RemoteAuthService _auth      = RemoteAuthService.instance;
  final _localNotifications          = FlutterLocalNotificationsPlugin();

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Save this device's FCM token to Firestore.
  /// Call this immediately after every successful login.
  /// Needed for future push notification support.
  Future<void> saveFcmToken() async {
    try {
      final userId = await _auth.userId;
      if (userId == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await _firestore.collection('users').doc(userId).update({
        'fcm_token':         token,
        'fcm_token_updated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[SosService] saveFcmToken error: $e');
    }
  }

  /// Trigger a full SOS alert for [memberName].
  /// Call this after the user confirms in the dialog.
  Future<SosResult> triggerSOS({required String memberName}) async {
    try {
      // 1. GPS location
      final position = await _getLocation();
      if (position == null) {
        return const SosResult(
          success: false,
          errorMessage:
              'Could not get GPS location. Please enable location services and try again.',
        );
      }

      // 2. Session info
      final familyId = await _auth.familyId;
      final userId   = await _auth.userId;
      if (familyId == null || userId == null) {
        return const SosResult(
          success: false,
          errorMessage: 'No active session. Please sign in again.',
        );
      }

      // 3. Write SOS alert document to Firestore
      // This triggers the in-app banner for all family members instantly
      final alertRef = _firestore.collection('sos_alerts').doc();
      await alertRef.set({
        'id':          alertRef.id,
        'family_id':   familyId,
        'sender_id':   userId,
        'member_name': memberName,
        'latitude':    position.latitude,
        'longitude':   position.longitude,
        'accuracy':    position.accuracy,
        'is_resolved': false,
        'created_at':  FieldValue.serverTimestamp(),
      });

      // 4. Local notification on the sender's own device
      await _showLocalConfirmation(memberName);

      return SosResult(
        success:       true,
        latitude:      position.latitude,
        longitude:     position.longitude,
        notifiedCount: 0,
      );
    } catch (e) {
      return SosResult(
        success:      false,
        errorMessage: 'SOS failed: $e',
      );
    }
  }

  /// Mark an SOS alert as resolved.
  /// Call this when a family member acknowledges the alert in-app.
  Future<void> resolveAlert(String alertId) async {
    try {
      await _firestore.collection('sos_alerts').doc(alertId).update({
        'is_resolved': true,
        'resolved_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[SosService] resolveAlert error: $e');
    }
  }

  /// Stream of active (unresolved) SOS alerts for the current family.
  /// Used by persistent_dashboard.dart to show the in-app emergency banner.
  Stream<List<Map<String, dynamic>>> activeAlertsStream() async* {
    final familyId = await _auth.familyId;
    if (familyId == null) {
      yield [];
      return;
    }
    yield* _firestore
        .collection('sos_alerts')
        .where('family_id', isEqualTo: familyId)
        .where('is_resolved', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Request location permission and return current position, or null on failure.
  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy:  LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      print('[SosService] _getLocation error: $e');
      return null;
    }
  }

  /// Show a local notification confirming the SOS was sent (on sender's device).
  Future<void> _showLocalConfirmation(String memberName) async {
    const androidDetails = AndroidNotificationDetails(
      'sos_alerts',
      'SOS Alerts',
      channelDescription: 'Emergency SOS alerts',
      importance:      Importance.max,
      priority:        Priority.high,
      enableVibration: true,
      playSound:       true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      '✅ SOS Sent',
      'Emergency alert sent for $memberName. Family members will be notified when they open the app.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}