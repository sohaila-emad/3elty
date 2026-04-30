# دليل إعداد نظام الإشعارات — تطبيق عيلتي

## الملفات المُضافة / المُعدَّلة

### ملف جديد
| الملف | الوصف |
|---|---|
| `lib/services/notification_helper.dart` | الكلاس الرئيسية لكل إشعارات التطبيق |

### ملفات معدَّلة
| الملف | التغيير |
|---|---|
| `pubspec.yaml` | إضافة `flutter_local_notifications: ^17.2.4` و `timezone: ^0.9.4` |
| `lib/main.dart` | استدعاء `NotificationHelper.instance.initialize()` عند بدء التطبيق |
| `lib/modules/medications_screen.dart` | جدولة تذكير يومي عند إضافة دواء، وإلغاؤه عند الحذف |
| `lib/modules/pregnancy_medications_screen.dart` | نفس منطق الأدوية لشاشة الحامل |
| `lib/modules/appointments_screen.dart` | جدولة تذكيرَين (يوم قبل + في اليوم ذاته) عند إضافة موعد |
| `lib/modules/vitals_screen.dart` | جدولة تذكير يومي الساعة 9 ص عند أول تسجيل حيوي |
| `lib/modules/vaccinations_screen.dart` | إشعار فوري عند تسجيل تطعيم + واجهة تسجيل كاملة |
| `android/app/src/main/AndroidManifest.xml` | أذونات `POST_NOTIFICATIONS`، `SCHEDULE_EXACT_ALARM`، `BOOT_COMPLETED` |

---

## خطوات التثبيت

### 1. تثبيت الحزم
```bash
flutter pub get
```

### 2. إعداد timezone (مهم)
الحزمة `timezone` تحتاج ملف بيانات. أضف هذا في `pubspec.yaml` تحت `flutter:`:
```yaml
flutter:
  assets:
    - packages/timezone/data/
```
> ملاحظة: إذا استخدمت `tz.initializeTimeZones()` من `timezone/data/latest.dart` فلا حاجة للـ assets.

### 3. Android - الحد الأدنى للـ SDK
تأكد أن `android/app/build.gradle.kts` يحتوي على:
```kotlin
minSdk = 21
```

### 4. iOS - Info.plist
أضف هذا في `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

---

## بنية نظام الإشعارات

```
NotificationHelper (Singleton)
│
├── قنوات الإشعارات
│   ├── medications_channel  → تذكيرات الأدوية
│   ├── appointments_channel → تذكيرات المواعيد
│   ├── vitals_channel       → تذكيرات العلامات الحيوية
│   └── vaccinations_channel → إشعارات التطعيمات
│
├── نطاقات المعرّفات
│   ├── 1000-1999 → الأدوية
│   ├── 2000-2999 → المواعيد
│   ├── 3000-3999 → العلامات الحيوية
│   └── 4000-4999 → التطعيمات
│
└── الدوال العامة
    ├── scheduleMedicationReminder()  → إشعار يومي متكرر
    ├── cancelMedicationReminder()    → إلغاء عند حذف الدواء
    ├── scheduleAppointmentReminder() → إشعار قبل يوم + في اليوم ذاته
    ├── cancelAppointmentReminder()   → إلغاء عند حذف الموعد
    ├── scheduleDailyVitalsReminder() → تذكير يومي الساعة 9 ص
    ├── cancelVitalsReminder()        → إلغاء التذكير اليومي
    └── notifyVaccinationLogged()     → إشعار فوري عند تسجيل تطعيم
```

---

## أمثلة على نصوص الإشعارات (كلها عربية)

| النوع | العنوان | النص |
|---|---|---|
| دواء | 💊 حان موعد الدواء | سارة — أسبرين (الصباح) |
| موعد (قبل يوم) | 📅 تذكير بموعد غداً | أحمد — كشف دوري مع د. محمد |
| موعد (في اليوم) | 🏥 موعد طبي اليوم | أحمد — كشف دوري |
| علامات حيوية | ❤️ وقت قياس العلامات الحيوية | لا تنسَ تسجيل قراءاتك اليومية يا محمود |
| تطعيم | ✅ تم تسجيل التطعيم | مريم — BCG |

---

## الاستدامة (Persistence)

- الإشعارات المجدولة **تثبت بعد إعادة تشغيل التطبيق** لأنها محفوظة في نظام Android/iOS.
- عند إعادة تشغيل الجهاز: `ScheduledNotificationBootReceiver` يعيد جدولة الإشعارات تلقائياً.
- الإشعار اليومي للأدوية يستخدم `matchDateTimeComponents: DateTimeComponents.time` للتكرار اليومي التلقائي.
