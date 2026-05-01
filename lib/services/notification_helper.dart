import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// ─── مساعد الإشعارات المحلية ─────────────────────────────────────────────────
///
/// هذه الكلاس تتحكم في كل إشعارات التطبيق: الأدوية، المواعيد،
/// العلامات الحيوية اليومية، والتطعيمات.
///
/// طريقة الاستخدام:
///   1. استدعِ [initialize] مرة واحدة في main()
///   2. استخدم الدوال المتخصصة من Repository أو الشاشات عند حفظ البيانات
/// ─────────────────────────────────────────────────────────────────────────────
class NotificationHelper {
  NotificationHelper._();
  static final NotificationHelper instance = NotificationHelper._();
  factory NotificationHelper() => instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── معرّفات قنوات الإشعار (Notification Channel IDs) ─────────────────────
  static const _channelMedications  = 'medications_channel';
  static const _channelAppointments = 'appointments_channel';
  static const _channelVitals       = 'vitals_channel';
  static const _channelVaccinations = 'vaccinations_channel';

  // ── نطاقات معرّفات الإشعارات (لتجنب التعارض بين الأنواع) ─────────────────
  static const int _medicationIdBase  = 1000;
  static const int _appointmentIdBase = 2000;
  static const int _vitalsIdBase      = 3000;
  static const int _vaccinationIdBase = 4000;

  // ─── التهيئة الأولى ────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;

    // تهيئة بيانات المناطق الزمنية
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

    // إعدادات Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // طلب الأذونات على Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationHelper] تم التهيئة بنجاح ✓');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationHelper] تم النقر على الإشعار: ${response.payload}');
  }

  // ─── دوال مساعدة خاصة ─────────────────────────────────────────────────────

  /// يحوّل نص إلى معرّف رقمي فريد
  int _stringToId(String text, int base) {
    return base + (text.hashCode.abs() % 1000);
  }

  /// ينشئ إعدادات Android لقناة معينة
  AndroidNotificationDetails _androidDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
    Color? color,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      color: color,
      playSound: true,
      enableLights: true,
      enableVibration: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. إشعارات الأدوية
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول إشعاراً يومياً متكرراً لدواء معين
  ///
  /// [medicationId]  : المعرّف الفريد للدواء
  /// [medicationName]: اسم الدواء بالعربية
  /// [memberName]    : اسم فرد العائلة
  /// [timeOfDay]     : وقت الجرعة (الصباح / الظهر / المساء / الليل)
  Future<void> scheduleMedicationReminder({
    required String medicationId,
    required String medicationName,
    required String memberName,
    required String timeOfDay,
  }) async {
    await initialize();

    final notifId = _stringToId(medicationId, _medicationIdBase);
    final time = _timeOfDayToTime(timeOfDay);

    final androidDetails = _androidDetails(
      channelId: _channelMedications,
      channelName: 'تذكيرات الأدوية',
      channelDesc: 'إشعارات يومية لمواعيد تناول الأدوية',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF00796B),
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      notifId,
      '💊 حان موعد الدواء',
      '$memberName — $medicationName ($timeOfDay)',
      _nextInstanceOfTime(time.hour, time.minute),
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // يتكرر يومياً
      payload: 'medication:$medicationId',
    );

    debugPrint('[NotificationHelper] تم جدولة تذكير دواء: $medicationName (ID: $notifId)');
  }

  /// يلغي إشعار دواء معين (عند الحذف)
  Future<void> cancelMedicationReminder(String medicationId) async {
    final notifId = _stringToId(medicationId, _medicationIdBase);
    await _plugin.cancel(notifId);
    debugPrint('[NotificationHelper] تم إلغاء تذكير الدواء: $medicationId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. إشعارات المواعيد
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول إشعاراً للموعد الطبي يوماً واحداً قبله وفي صباح يومه
  ///
  /// [appointmentId]: المعرّف الفريد للموعد
  /// [title]        : عنوان الموعد
  /// [memberName]   : اسم فرد العائلة
  /// [doctor]       : اسم الطبيب (اختياري)
  /// [scheduledAt]  : تاريخ الموعد (ISO string: "2025-01-15")
  Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required String title,
    required String memberName,
    String? doctor,
    required String scheduledAt,
  }) async {
    await initialize();

    DateTime? apptDate;
    try {
      apptDate = DateTime.parse(scheduledAt);
    } catch (_) {
      debugPrint('[NotificationHelper] تاريخ موعد غير صالح: $scheduledAt');
      return;
    }

    if (apptDate.isBefore(DateTime.now())) return;

    final doctorText = doctor != null ? ' مع $doctor' : '';
    final body = '$memberName — $title$doctorText';

    final androidDetails = _androidDetails(
      channelId: _channelAppointments,
      channelName: 'تذكيرات المواعيد',
      channelDesc: 'إشعارات مواعيد الأطباء والمتابعات',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF1565C0),
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    // إشعار قبل يوم واحد (الساعة 10 صباحاً)
    final dayBefore = DateTime(
      apptDate.year, apptDate.month, apptDate.day - 1, 10, 0,
    );
    if (dayBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _stringToId('${appointmentId}_day', _appointmentIdBase),
        '📅 تذكير بموعد غداً',
        body,
        tz.TZDateTime.from(dayBefore, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'appointment:$appointmentId',
      );
    }

    // إشعار في يوم الموعد (الساعة 8 صباحاً)
    final dayOf = DateTime(
      apptDate.year, apptDate.month, apptDate.day, 8, 0,
    );
    if (dayOf.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        _stringToId('${appointmentId}_same', _appointmentIdBase),
        '🏥 موعد طبي اليوم',
        body,
        tz.TZDateTime.from(dayOf, tz.local),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'appointment:$appointmentId',
      );
    }

    debugPrint('[NotificationHelper] تم جدولة تذكيرَي الموعد: $title');
  }

  /// يلغي إشعارات الموعد (عند الحذف)
  Future<void> cancelAppointmentReminder(String appointmentId) async {
    await _plugin.cancel(_stringToId('${appointmentId}_day', _appointmentIdBase));
    await _plugin.cancel(_stringToId('${appointmentId}_same', _appointmentIdBase));
    debugPrint('[NotificationHelper] تم إلغاء تذكيرات الموعد: $appointmentId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. إشعارات العلامات الحيوية اليومية
  // ═══════════════════════════════════════════════════════════════════════════

  /// يجدول تذكيراً يومياً لتسجيل العلامات الحيوية
  ///
  /// [memberId]  : معرّف فرد العائلة
  /// [memberName]: اسم فرد العائلة
  /// [hour]      : ساعة الإشعار (افتراضي: 9 صباحاً)
  /// [minute]    : دقيقة الإشعار
  Future<void> scheduleDailyVitalsReminder({
    required String memberId,
    required String memberName,
    int hour = 9,
    int minute = 0,
  }) async {
    await initialize();

    final notifId = _stringToId('vitals_$memberId', _vitalsIdBase);

    final androidDetails = _androidDetails(
      channelId: _channelVitals,
      channelName: 'تذكيرات العلامات الحيوية',
      channelDesc: 'تذكير يومي لتسجيل ضغط الدم والسكر والمزيد',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: const Color(0xFFE65100),
    );

    await _plugin.zonedSchedule(
      notifId,
      '❤️ وقت قياس العلامات الحيوية',
      'لا تنسَ تسجيل قراءاتك اليومية يا $memberName',
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // يتكرر يومياً
      payload: 'vitals:$memberId',
    );

    debugPrint('[NotificationHelper] تم جدولة تذكير العلامات الحيوية لـ: $memberName');
  }

  /// يلغي التذكير اليومي للعلامات الحيوية
  Future<void> cancelVitalsReminder(String memberId) async {
    final notifId = _stringToId('vitals_$memberId', _vitalsIdBase);
    await _plugin.cancel(notifId);
    debugPrint('[NotificationHelper] تم إلغاء تذكير العلامات الحيوية لـ: $memberId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. إشعارات التطعيمات
  // ═══════════════════════════════════════════════════════════════════════════

  /// يرسل إشعاراً فورياً عند تسجيل تطعيم جديد
  Future<void> notifyVaccinationLogged({
    required String vaccineName,
    required String memberName,
  }) async {
    await initialize();

    final notifId = _stringToId('${vaccineName}_$memberName', _vaccinationIdBase);

    final androidDetails = _androidDetails(
      channelId: _channelVaccinations,
      channelName: 'التطعيمات',
      channelDesc: 'إشعارات جدول التطعيمات للأطفال',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: const Color(0xFF1565C0),
    );

    await _plugin.show(
      notifId,
      '✅ تم تسجيل التطعيم',
      '$memberName — $vaccineName',
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      payload: 'vaccination:$vaccineName',
    );

    debugPrint('[NotificationHelper] تم إرسال إشعار التطعيم: $vaccineName');
  }

  /// يجدول تذكيراً بموعد تطعيم قادم (قبل 3 أيام)
  Future<void> scheduleVaccinationReminder({
    required String vaccineId,
    required String vaccineName,
    required String memberName,
    required DateTime scheduledDate,
  }) async {
    await initialize();

    if (scheduledDate.isBefore(DateTime.now())) return;

    final notifId = _stringToId(vaccineId, _vaccinationIdBase);
    final reminderDate = scheduledDate.subtract(const Duration(days: 3));
    if (reminderDate.isBefore(DateTime.now())) return;

    final androidDetails = _androidDetails(
      channelId: _channelVaccinations,
      channelName: 'التطعيمات',
      channelDesc: 'إشعارات جدول التطعيمات للأطفال',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFF1565C0),
    );

    final reminderTime = DateTime(
      reminderDate.year, reminderDate.month, reminderDate.day, 10, 0,
    );

    await _plugin.zonedSchedule(
      notifId,
      '💉 موعد تطعيم قريب',
      '$memberName — $vaccineName بعد 3 أيام',
      tz.TZDateTime.from(reminderTime, tz.local),
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'vaccination:$vaccineId',
    );

    debugPrint('[NotificationHelper] تم جدولة تذكير التطعيم: $vaccineName');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إدارة الإشعارات
  // ═══════════════════════════════════════════════════════════════════════════

  /// يلغي كل الإشعارات المجدولة
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[NotificationHelper] تم إلغاء كل الإشعارات');
  }

  /// يلغي إشعاراً واحداً بمعرّفه
  Future<void> cancelById(int id) async {
    await _plugin.cancel(id);
  }

  // ─── دوال مساعدة خاصة ─────────────────────────────────────────────────────

  /// يحوّل وقت الجرعة النصي إلى ساعة ودقيقة
  ({int hour, int minute}) _timeOfDayToTime(String timeOfDay) {
    switch (timeOfDay) {
      case 'الصباح':
        return (hour: 8, minute: 0);
      case 'الظهر':
        return (hour: 12, minute: 30);
      case 'المساء':
        return (hour: 17, minute: 0);
      case 'الليل':
        return (hour: 21, minute: 0);
      default:
        return (hour: 9, minute: 0);
    }
  }

  /// يحسب أقرب وقت قادم لساعة ودقيقة محددتين (اليوم أو الغد)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
