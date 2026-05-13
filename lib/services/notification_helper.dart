import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// ─── مساعد الإشعارات المحلية ────────────────────────────────────────────────
///
/// الإصلاحات المطبّقة في هذا الإصدار:
///   1. لا يعتمد على permission_handler — يستخدم واجهة FLN الأصلية فقط
///   2. يطلب SCHEDULE_EXACT_ALARM عبر FLN فقط على API 31+ (لا كراش على API < 31)
///   3. يتحقق من منح الإذن قبل استخدام exactAllowWhileIdle، ويتراجع لـ inexact
///   4. _nextInstanceOfTime تضيف هامش دقيقتين لتجنّب الجدولة في الماضي المباشر
///   5. نطاق معرّفات أوسع (9999 فتحة × قاعدة 10000) لتجنّب التعارض
///   6. القنوات تُنشأ مسبقاً في Application.kt — هنا فقط نتحقق من التهيئة
///
/// طريقة الاستخدام:
///   1. استدعِ [initialize] مرة واحدة في main() قبل runApp()
///   2. استخدم الدوال المتخصصة عند حفظ البيانات
/// ────────────────────────────────────────────────────────────────────────────
class NotificationHelper {
  NotificationHelper._();
  static final NotificationHelper instance = NotificationHelper._();
  factory NotificationHelper() => instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Channel IDs — must match Application.kt exactly ─────────────────────
  static const _channelMedications  = 'medications_channel';
  static const _channelAppointments = 'appointments_channel';
  static const _channelVitals       = 'vitals_channel';
  static const _channelVaccinations = 'vaccinations_channel';

  // ── ID bases: 10 000-unit gaps, 9 999 slots each ─────────────────────────
  static const int _medicationIdBase  = 10000;
  static const int _appointmentIdBase = 20000;
  static const int _vitalsIdBase      = 30000;
  static const int _vaccinationIdBase = 40000;

  // ─── Initialisation ──────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    // Timezone data — must be called before any zonedSchedule
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // POST_NOTIFICATIONS — Android 13+ (API 33)
      await androidImpl?.requestNotificationsPermission();

      // SCHEDULE_EXACT_ALARM — Android 12+ (API 31).
      // requestExactAlarmsPermission() is a no-op below API 31, so no crash.
      await androidImpl?.requestExactAlarmsPermission();
    }

    _initialized = true;
    debugPrint('[NotificationHelper] initialised ✓');
  }

  void _onNotificationTapped(NotificationResponse r) {
    debugPrint('[NotificationHelper] tapped: ${r.payload}');
  }

  // ─── Helper: choose exact vs inexact based on granted permission ─────────
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // areNotificationsEnabled() returns false if permission denied — treat as
    // safe proxy; exact alarm status is checked via canScheduleExactNotifications
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ─── Helper: string → unique notification ID ─────────────────────────────
  int _idFor(String key, int base) => base + (key.hashCode.abs() % 9999);

  // ─── Helper: Android channel details ─────────────────────────────────────
  AndroidNotificationDetails _android({
    required String channelId,
    required String channelName,
    required String channelDesc,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    Color? color,
  }) =>
      AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: channelDesc,
        importance: importance,
        priority: priority,
        color: color,
        playSound: true,
        enableLights: true,
        enableVibration: true,
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // 1.  Medication reminders
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String medicationName,
    required String memberName,
    required int hour,
    required int minute,
  }) async {
    await initialize();

    final id   = _idFor(medicationId, _medicationIdBase);
    final mode = await _scheduleMode();

    await _plugin.zonedSchedule(
      id,
      '💊 حان موعد الدواء',
      '$memberName — $medicationName (${_fmt(hour, minute)})',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: _android(
          channelId: _channelMedications,
          channelName: 'تذكيرات الأدوية',
          channelDesc: 'إشعارات يومية لمواعيد تناول الأدوية',
          color: const Color(0xFF00796B),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      payload: 'medication:$medicationId',
    );

    debugPrint('[NotificationHelper] medication scheduled: $medicationName '
        '${_fmt(hour, minute)} (id=$id, mode=$mode)');
  }

  Future<void> cancelMedicationReminder(String medicationId) async {
    await _plugin.cancel(_idFor(medicationId, _medicationIdBase));
    debugPrint('[NotificationHelper] medication cancelled: $medicationId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2.  Appointment reminders  (day-before @ 10:00 + same-day @ 08:00)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String title,
    required String memberName,
    String? doctor,
    required String scheduledAt, // ISO date string "2025-01-15"
  }) async {
    await initialize();

    DateTime apptDate;
    try {
      apptDate = DateTime.parse(scheduledAt);
    } catch (_) {
      debugPrint('[NotificationHelper] invalid appointment date: $scheduledAt');
      return;
    }
    if (apptDate.isBefore(DateTime.now())) return;

    final body   = '$memberName — $title${doctor != null ? ' مع $doctor' : ''}';
    final mode   = await _scheduleMode();
    final details = NotificationDetails(
      android: _android(
        channelId: _channelAppointments,
        channelName: 'تذكيرات المواعيد',
        channelDesc: 'إشعارات مواعيد الأطباء والمتابعات',
        color: const Color(0xFF1565C0),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      ),
    );

    final dayBefore = DateTime(
        apptDate.year, apptDate.month, apptDate.day - 1, 10, 0);
    if (dayBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _idFor('${appointmentId}_day', _appointmentIdBase),
        '📅 تذكير بموعد غداً', body,
        tz.TZDateTime.from(dayBefore, tz.local),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'appointment:$appointmentId',
      );
    }

    final dayOf = DateTime(apptDate.year, apptDate.month, apptDate.day, 8, 0);
    if (dayOf.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _idFor('${appointmentId}_same', _appointmentIdBase),
        '🏥 موعد طبي اليوم', body,
        tz.TZDateTime.from(dayOf, tz.local),
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'appointment:$appointmentId',
      );
    }

    debugPrint('[NotificationHelper] appointment scheduled: $title');
  }

  Future<void> cancelAppointmentReminder(String appointmentId) async {
    await _plugin.cancel(_idFor('${appointmentId}_day',  _appointmentIdBase));
    await _plugin.cancel(_idFor('${appointmentId}_same', _appointmentIdBase));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3.  Daily vitals reminder
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> scheduleDailyVitalsReminder({
    required String memberId,
    required String memberName,
    int hour = 9,
    int minute = 0,
  }) async {
    await initialize();

    final mode = await _scheduleMode();

    await _plugin.zonedSchedule(
      _idFor('vitals_$memberId', _vitalsIdBase),
      '❤️ وقت قياس العلامات الحيوية',
      'لا تنسَ تسجيل قراءاتك اليومية يا $memberName',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: _android(
          channelId: _channelVitals,
          channelName: 'تذكيرات العلامات الحيوية',
          channelDesc: 'تذكير يومي لتسجيل ضغط الدم والسكر والمزيد',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFFE65100),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: false, presentSound: true,
        ),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'vitals:$memberId',
    );

    debugPrint('[NotificationHelper] vitals reminder scheduled for $memberName');
  }

  Future<void> cancelVitalsReminder(String memberId) async {
    await _plugin.cancel(_idFor('vitals_$memberId', _vitalsIdBase));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4.  Vaccination notifications
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> notifyVaccinationLogged({
    required String vaccineName,
    required String memberName,
  }) async {
    await initialize();

    await _plugin.show(
      _idFor('${vaccineName}_$memberName', _vaccinationIdBase),
      '✅ تم تسجيل التطعيم',
      '$memberName — $vaccineName',
      NotificationDetails(
        android: _android(
          channelId: _channelVaccinations,
          channelName: 'التطعيمات',
          channelDesc: 'إشعارات جدول التطعيمات للأطفال',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFF1565C0),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: false,
        ),
      ),
      payload: 'vaccination:$vaccineName',
    );
  }

  Future<void> scheduleVaccinationReminder({
    required String vaccineId,
    required String vaccineName,
    required String memberName,
    required DateTime scheduledDate,
  }) async {
    await initialize();

    if (scheduledDate.isBefore(DateTime.now())) return;

    final reminderDate = scheduledDate.subtract(const Duration(days: 3));
    if (reminderDate.isBefore(DateTime.now())) return;

    final mode = await _scheduleMode();
    final reminderTime = DateTime(
        reminderDate.year, reminderDate.month, reminderDate.day, 10, 0);

    await _plugin.zonedSchedule(
      _idFor(vaccineId, _vaccinationIdBase),
      '💉 موعد تطعيم قريب',
      '$memberName — $vaccineName بعد 3 أيام',
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: _android(
          channelId: _channelVaccinations,
          channelName: 'التطعيمات',
          channelDesc: 'إشعارات جدول التطعيمات للأطفال',
          color: const Color(0xFF1565C0),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
        ),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'vaccination:$vaccineId',
    );

    debugPrint('[NotificationHelper] vaccination reminder scheduled: $vaccineName');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Management
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[NotificationHelper] all cancelled');
  }

  Future<void> cancelById(int id) => _plugin.cancel(id);

  // ─── Private helpers ──────────────────────────────────────────────────────

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// Returns the next future occurrence of [hour]:[minute] in local time.
  /// Adds a 2-minute safety buffer so a notification saved "just now" is
  /// always pushed to tomorrow rather than silently dropped as past.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now.add(const Duration(minutes: 2)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }
}