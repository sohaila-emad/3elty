import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

// ─── معايير منظمة الصحة العالمية (WHO) للوزن والطول ──────────────────────────
//
// العمر مخزَّن دائماً بالشهور للأطفال في قاعدة البيانات.
// المصدر: WHO Child Growth Standards 2006
// ─────────────────────────────────────────────────────────────────────────────

/// يُرجع النطاق الطبيعي لمنظمة الصحة العالمية للوزن (كجم) بناءً على العمر
/// [ageInMonths] = عمر الطفل بالشهور
Map<String, dynamic> whoWeightRange(int ageInMonths) {
  if (ageInMonths <= 1)   return {'min': 2.9,  'max': 5.1,  'label': 'حديث الولادة'};
  if (ageInMonths <= 3)   return {'min': 4.4,  'max': 7.4,  'label': '1-3 أشهر'};
  if (ageInMonths <= 6)   return {'min': 5.7,  'max': 9.2,  'label': '3-6 أشهر'};
  if (ageInMonths <= 9)   return {'min': 6.9,  'max': 10.9, 'label': '6-9 أشهر'};
  if (ageInMonths <= 12)  return {'min': 7.7,  'max': 11.9, 'label': '9-12 شهراً'};
  if (ageInMonths <= 18)  return {'min': 8.8,  'max': 13.7, 'label': '1-1.5 سنة'};
  if (ageInMonths <= 24)  return {'min': 9.7,  'max': 15.3, 'label': '1.5-2 سنة'};
  if (ageInMonths <= 36)  return {'min': 11.0, 'max': 18.3, 'label': '2-3 سنوات'};
  if (ageInMonths <= 48)  return {'min': 12.7, 'max': 21.2, 'label': '3-4 سنوات'};
  if (ageInMonths <= 60)  return {'min': 14.1, 'max': 24.2, 'label': '4-5 سنوات'};
  if (ageInMonths <= 72)  return {'min': 15.9, 'max': 27.1, 'label': '5-6 سنوات'};
  if (ageInMonths <= 84)  return {'min': 17.7, 'max': 30.7, 'label': '6-7 سنوات'};
  if (ageInMonths <= 96)  return {'min': 19.5, 'max': 35.5, 'label': '7-8 سنوات'};
  if (ageInMonths <= 108) return {'min': 21.8, 'max': 40.9, 'label': '8-9 سنوات'};
  if (ageInMonths <= 120) return {'min': 24.0, 'max': 46.9, 'label': '9-10 سنوات'};
  if (ageInMonths <= 132) return {'min': 26.8, 'max': 53.7, 'label': '10-11 سنة'};
  if (ageInMonths <= 144) return {'min': 30.0, 'max': 61.2, 'label': '11-12 سنة'};
  if (ageInMonths <= 156) return {'min': 33.8, 'max': 67.8, 'label': '12-13 سنة'};
  if (ageInMonths <= 168) return {'min': 38.0, 'max': 73.5, 'label': '13-14 سنة'};
  if (ageInMonths <= 180) return {'min': 42.5, 'max': 78.2, 'label': '14-15 سنة'};
  if (ageInMonths <= 192) return {'min': 46.8, 'max': 81.0, 'label': '15-16 سنة'};
  if (ageInMonths <= 204) return {'min': 50.2, 'max': 82.8, 'label': '16-17 سنة'};
  return                         {'min': 52.9, 'max': 84.0, 'label': '17-18 سنة'};
}

/// يُرجع النطاق الطبيعي لمنظمة الصحة العالمية للطول (سم) بناءً على العمر
Map<String, dynamic> whoHeightRange(int ageInMonths) {
  if (ageInMonths <= 1)   return {'min': 48.0, 'max': 55.6,  'label': 'حديث الولادة'};
  if (ageInMonths <= 3)   return {'min': 55.6, 'max': 63.2,  'label': '1-3 أشهر'};
  if (ageInMonths <= 6)   return {'min': 61.2, 'max': 70.3,  'label': '3-6 أشهر'};
  if (ageInMonths <= 9)   return {'min': 66.3, 'max': 75.9,  'label': '6-9 أشهر'};
  if (ageInMonths <= 12)  return {'min': 70.1, 'max': 80.5,  'label': '9-12 شهراً'};
  if (ageInMonths <= 18)  return {'min': 74.2, 'max': 85.7,  'label': '1-1.5 سنة'};
  if (ageInMonths <= 24)  return {'min': 81.7, 'max': 93.9,  'label': '1.5-2 سنة'};
  if (ageInMonths <= 36)  return {'min': 88.7, 'max': 102.7, 'label': '2-3 سنوات'};
  if (ageInMonths <= 48)  return {'min': 95.0, 'max': 111.3, 'label': '3-4 سنوات'};
  if (ageInMonths <= 60)  return {'min': 100.7,'max': 118.9, 'label': '4-5 سنوات'};
  if (ageInMonths <= 72)  return {'min': 106.1,'max': 125.8, 'label': '5-6 سنوات'};
  if (ageInMonths <= 84)  return {'min': 111.2,'max': 132.2, 'label': '6-7 سنوات'};
  if (ageInMonths <= 96)  return {'min': 116.0,'max': 137.9, 'label': '7-8 سنوات'};
  if (ageInMonths <= 108) return {'min': 120.5,'max': 143.6, 'label': '8-9 سنوات'};
  if (ageInMonths <= 120) return {'min': 124.9,'max': 149.0, 'label': '9-10 سنوات'};
  if (ageInMonths <= 132) return {'min': 129.5,'max': 154.5, 'label': '10-11 سنة'};
  if (ageInMonths <= 144) return {'min': 134.5,'max': 159.5, 'label': '11-12 سنة'};
  if (ageInMonths <= 156) return {'min': 139.5,'max': 165.0, 'label': '12-13 سنة'};
  if (ageInMonths <= 168) return {'min': 144.5,'max': 169.8, 'label': '13-14 سنة'};
  if (ageInMonths <= 180) return {'min': 150.0,'max': 174.1, 'label': '14-15 سنة'};
  if (ageInMonths <= 192) return {'min': 154.0,'max': 177.0, 'label': '15-16 سنة'};
  if (ageInMonths <= 204) return {'min': 157.0,'max': 179.0, 'label': '16-17 سنة'};
  return                         {'min': 159.0,'max': 180.5, 'label': '17-18 سنة'};
}

/// يُرجع تغذية راجعة ذكية (حالة + لون) بناءً على القياس ومعايير WHO
Map<String, dynamic> getWhoFeedback({
  required String type,
  required double value,
  required int ageInMonths,
}) {
  final range = type == 'weight'
      ? whoWeightRange(ageInMonths)
      : whoHeightRange(ageInMonths);

  final double min = (range['min'] as num).toDouble();
  final double max = (range['max'] as num).toDouble();

  if (type == 'weight') {
    if (value < min * 0.85)  return {'msg': 'نقص حاد في الوزن',      'color': Colors.red[700]!,    'status': 'low'};
    if (value < min)         return {'msg': 'أقل من المعدل الطبيعي', 'color': Colors.orange,       'status': 'low'};
    if (value > max * 1.15)  return {'msg': 'زيادة واضحة في الوزن',  'color': Colors.orange[800]!, 'status': 'high'};
    if (value > max)         return {'msg': 'فوق المعدل الطبيعي',    'color': Colors.orange,       'status': 'high'};
    return                          {'msg': 'وزن طبيعي وصحي ✓',      'color': Colors.green[700]!,  'status': 'ok'};
  } else {
    if (value < min * 0.93)  return {'msg': 'قصر نمو ملحوظ',         'color': Colors.red[700]!,    'status': 'low'};
    if (value < min)         return {'msg': 'أقل من متوسط الطول',    'color': Colors.orange,       'status': 'low'};
    if (value > max * 1.07)  return {'msg': 'طول فوق المتوسط',       'color': Colors.blue[700]!,   'status': 'high'};
    if (value > max)         return {'msg': 'فوق المتوسط قليلاً',    'color': Colors.blue,         'status': 'high'};
    return                          {'msg': 'طول طبيعي وصحي ✓',      'color': Colors.green[700]!,  'status': 'ok'};
  }
}

// ─── محرك التحقق من صحة قياسات النمو ────────────────────────────────────────
//
// المستويات:
//   ok      → القيمة ضمن المعدل أو قريبة منه. يُسمح بالحفظ.
//   warning → خارج نطاق WHO لكن ممكن بيولوجياً. يُسمح بالحفظ بعد تأكيد.
//   severe  → بعيد جداً عن المعدل الطبيعي. نادر جداً. يُسمح بالحفظ بعد تأكيد مزدوج.
//   invalid → مستحيل بيولوجياً أو خطأ إدخال مؤكد. يُمنع الحفظ تماماً.
// ─────────────────────────────────────────────────────────────────────────────

enum GrowthValidationLevel { ok, warning, severe, invalid }

class GrowthValidationResult {
  final GrowthValidationLevel level;
  final String message;

  const GrowthValidationResult(this.level, this.message);

  /// يمنع الحفظ فقط عند invalid
  bool get blocksSubmit => level == GrowthValidationLevel.invalid;

  Color get color {
    switch (level) {
      case GrowthValidationLevel.ok:      return Colors.green;
      case GrowthValidationLevel.warning: return Colors.orange;
      case GrowthValidationLevel.severe:  return Colors.deepOrange;
      case GrowthValidationLevel.invalid: return Colors.red[700]!;
    }
  }

  IconData get icon {
    switch (level) {
      case GrowthValidationLevel.ok:      return Icons.check_circle_outline;
      case GrowthValidationLevel.warning: return Icons.info_outline_rounded;
      case GrowthValidationLevel.severe:  return Icons.warning_amber_rounded;
      case GrowthValidationLevel.invalid: return Icons.cancel_rounded;
    }
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// [validateSingleMeasurement]
///
/// يُقيّم قياساً واحداً (طول أو وزن) بالنسبة لعمر الطفل بالشهور.
///
/// الحدود المطلقة (invalid):
///   قيم لا يمكن أن يصلها طفل في هذا العمر حتى في أنادر الحالات الطبية.
///   مستمدة من أعلى نطاق WHO + هامش سخي للحالات الاستثنائية.
///   أي قيمة تتخطى هذا الهامش = خطأ إدخال مؤكد → يُمنع الحفظ.
///
/// حدود الشدة (severe):
///   > 130% من الحد الأعلى لـ WHO، أو < 70% من الحد الأدنى.
///   بيولوجياً ممكن لكن نادر جداً → يُحذّر ويطلب تأكيد.
///
/// حدود التحذير (warning):
///   خارج نطاق WHO لكن دون 130% أعلى أو أكثر من 70% أدنى.
///   شائع في الأطفال ذوي النمو المختلف → ينبّه فقط.
/// ─────────────────────────────────────────────────────────────────────────────
GrowthValidationResult validateSingleMeasurement(
    String type, double value, int ageInMonths) {

  // ── 1. الحدود المطلقة الشاملة ──────────────────────────────────────────────
  if (type == 'height') {
    if (value < 20 || value > 220) {
      return const GrowthValidationResult(
          GrowthValidationLevel.invalid,
          '⛔ قيمة الطول خارج النطاق المقبول (20–220 سم) — يرجى التحقق من الإدخال');
    }
  } else {
    if (value < 0.5 || value > 200) {
      return const GrowthValidationResult(
          GrowthValidationLevel.invalid,
          '⛔ قيمة الوزن خارج النطاق المقبول (0.5–200 كجم) — يرجى التحقق من الإدخال');
    }
  }

  // ── 2. الحدود المطلقة حسب الفئة العمرية (invalid) ─────────────────────────
  //
  //  الحد = أعلى نطاق WHO لهذا العمر × 1.55  (هامش سخي جداً للحالات النادرة).
  //  أي قيمة تتجاوز هذا الحد = مستحيل بيولوجياً = يُمنع الحفظ.
  //
  //  جدول الحدود للطول (سم):
  //    < 3 أشهر  → ≤ 86    (max WHO 55.6 × 1.55 ≈ 86)
  //    < 6 أشهر  → ≤ 109   (max 70.3 × 1.55)
  //    < 12 أشهر → ≤ 125   (max 80.5 × 1.55)
  //    < 24 أشهر → ≤ 146   (max 93.9 × 1.55)
  //    < 36 أشهر → ≤ 159   (max 102.7 × 1.55)
  //    < 48 أشهر → ≤ 172   (max 111.3 × 1.55)
  //    < 60 أشهر → ≤ 184   (max 118.9 × 1.55)
  //    < 84 أشهر → ≤ 205   (max 132.2 × 1.55)
  //
  //  جدول الحدود للوزن (كجم):
  //    < 3 أشهر  → ≤ 11.5  (max 7.4 × 1.55)
  //    < 6 أشهر  → ≤ 14.3  (max 9.2 × 1.55)
  //    < 12 أشهر → ≤ 18.5  (max 11.9 × 1.55)
  //    < 24 أشهر → ≤ 23.7  (max 15.3 × 1.55)
  //    < 36 أشهر → ≤ 28.4  (max 18.3 × 1.55)
  //    < 48 أشهر → ≤ 32.9  (max 21.2 × 1.55)
  //    < 60 أشهر → ≤ 37.5  (max 24.2 × 1.55)
  //    < 84 أشهر → ≤ 47.6  (max 30.7 × 1.55)

  if (type == 'height') {
    String? invalidMsg;
    if      (ageInMonths < 3  && value > 86)   invalidMsg = '⛔ الطول مستحيل لطفل دون 3 أشهر';
    else if (ageInMonths < 6  && value > 109)  invalidMsg = '⛔ الطول مستحيل لطفل دون 6 أشهر';
    else if (ageInMonths < 12 && value > 125)  invalidMsg = '⛔ الطول مستحيل لرضيع دون سنة';
    else if (ageInMonths < 24 && value > 146)  invalidMsg = '⛔ الطول مستحيل لطفل دون سنتين';
    else if (ageInMonths < 36 && value > 159)  invalidMsg = '⛔ الطول مستحيل لطفل دون 3 سنوات';
    else if (ageInMonths < 48 && value > 172)  invalidMsg = '⛔ الطول مستحيل لطفل دون 4 سنوات';
    else if (ageInMonths < 60 && value > 184)  invalidMsg = '⛔ الطول مستحيل لطفل دون 5 سنوات';
    else if (ageInMonths < 84 && value > 205)  invalidMsg = '⛔ الطول مستحيل لطفل دون 7 سنوات';
    if (invalidMsg != null) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '$invalidMsg — يرجى التحقق من الإدخال');
    }
  } else {
    String? invalidMsg;
    if      (ageInMonths < 3  && value > 11.5) invalidMsg = '⛔ الوزن مستحيل لطفل دون 3 أشهر';
    else if (ageInMonths < 6  && value > 14.3) invalidMsg = '⛔ الوزن مستحيل لطفل دون 6 أشهر';
    else if (ageInMonths < 12 && value > 18.5) invalidMsg = '⛔ الوزن مستحيل لرضيع دون سنة';
    else if (ageInMonths < 24 && value > 23.7) invalidMsg = '⛔ الوزن مستحيل لطفل دون سنتين';
    else if (ageInMonths < 36 && value > 28.4) invalidMsg = '⛔ الوزن مستحيل لطفل دون 3 سنوات';
    else if (ageInMonths < 48 && value > 32.9) invalidMsg = '⛔ الوزن مستحيل لطفل دون 4 سنوات';
    else if (ageInMonths < 60 && value > 37.5) invalidMsg = '⛔ الوزن مستحيل لطفل دون 5 سنوات';
    else if (ageInMonths < 84 && value > 47.6) invalidMsg = '⛔ الوزن مستحيل لطفل دون 7 سنوات';
    if (invalidMsg != null) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '$invalidMsg — يرجى التحقق من الإدخال');
    }
  }

  // ── 3. مقارنة بنطاق WHO (severe / warning / ok) ──────────────────────────
  final range = type == 'weight'
      ? whoWeightRange(ageInMonths)
      : whoHeightRange(ageInMonths);
  final double whoMin = (range['min'] as num).toDouble();
  final double whoMax = (range['max'] as num).toDouble();
  final String label  = range['label'] as String;

  if (type == 'weight') {
    if (value < whoMin * 0.70) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن منخفض جداً جداً للعمر ($label) — يُنصح بمراجعة الطبيب فورًا');
    }
    if (value < whoMin) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الوزن أقل من النطاق الطبيعي للعمر ($label)');
    }
    if (value > whoMax * 1.30) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن مرتفع جداً جداً للعمر ($label) — يُنصح بمراجعة الطبيب');
    }
    if (value > whoMax) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الوزن فوق النطاق الطبيعي للعمر ($label)');
    }
  } else {
    if (value < whoMin * 0.85) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الطول منخفض جداً للعمر ($label) — يُنصح بمراجعة الطبيب');
    }
    if (value < whoMin) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الطول أقل من متوسط النطاق الطبيعي للعمر ($label)');
    }
    if (value > whoMax * 1.30) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الطول مرتفع جداً للعمر ($label) — يُنصح بمراجعة الطبيب');
    }
    if (value > whoMax) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الطول فوق متوسط النطاق الطبيعي للعمر ($label)');
    }
  }

  return const GrowthValidationResult(GrowthValidationLevel.ok, '');
}

/// ─────────────────────────────────────────────────────────────────────────────
/// [validateHeightWeightConsistency]
///
/// يتحقق من اتساق الطول مع الوزن عند إدخالهما معاً.
/// يُرجع null إن كانا متناسقَين أو GrowthValidationResult عند وجود تعارض.
///
/// للأطفال ≥ 24 شهراً: يستخدم BMI.
///   invalid  → BMI < 7  أو > 40  (مستحيل بيولوجياً)
///   severe   → BMI < 10 أو > 30  (نادر جداً)
///   warning  → BMI < 12.5 أو > 25
///
/// للرضع < 24 شهراً: يستخدم نسبة وزن/طول (weight-for-length).
///   invalid  → وزن < 65% أو > 135% من المدى المتوقع
///   severe   → وزن < 80% أو > 120% من المدى المتوقع
/// ─────────────────────────────────────────────────────────────────────────────
GrowthValidationResult? validateHeightWeightConsistency(
    double heightCm, double weightKg, int ageInMonths) {
  if (heightCm <= 0 || weightKg <= 0) return null;

  if (ageInMonths >= 24) {
    final heightM = heightCm / 100.0;
    final bmi = weightKg / (heightM * heightM);
    final bmiStr = bmi.toStringAsFixed(1);

    if (bmi < 7.0) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '⛔ الوزن والطول متعارضان تماماً: مؤشر كتلة الجسم = $bmiStr — يرجى تصحيح الأرقام');
    }
    if (bmi > 40.0) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '⛔ الوزن والطول متعارضان تماماً: مؤشر كتلة الجسم = $bmiStr — يرجى تصحيح الأرقام');
    }
    if (bmi < 10.0) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن منخفض جداً بالنسبة للطول (BMI = $bmiStr) — يُنصح بمراجعة الطبيب فورًا');
    }
    if (bmi > 30.0) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن مرتفع جداً بالنسبة للطول (BMI = $bmiStr) — يُنصح بمراجعة الطبيب');
    }
    if (bmi < 12.5) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الوزن منخفض نسبياً مقارنةً بالطول (BMI = $bmiStr)');
    }
    if (bmi > 25.0) {
      return GrowthValidationResult(GrowthValidationLevel.warning,
          'الوزن مرتفع نسبياً مقارنةً بالطول (BMI = $bmiStr)');
    }
  } else {
    // رضع: weight-for-length  المدى التقريبي [heightCm/14, heightCm/5]
    final expectedMin = heightCm / 14.0;
    final expectedMax = heightCm / 5.0;

    if (weightKg < expectedMin * 0.65) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '⛔ الوزن والطول متعارضان للرضيع — يرجى التحقق من الأرقام');
    }
    if (weightKg > expectedMax * 1.35) {
      return GrowthValidationResult(GrowthValidationLevel.invalid,
          '⛔ الوزن والطول متعارضان للرضيع — يرجى التحقق من الأرقام');
    }
    if (weightKg < expectedMin * 0.80) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن منخفض جداً بالنسبة لطول الرضيع — يُنصح بمراجعة الطبيب فورًا');
    }
    if (weightKg > expectedMax * 1.20) {
      return GrowthValidationResult(GrowthValidationLevel.severe,
          '⚠️ الوزن مرتفع جداً بالنسبة لطول الرضيع — يُنصح بمراجعة الطبيب');
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────

class GrowthTrackingScreen extends StatefulWidget {
  final FamilyMember member;
  const GrowthTrackingScreen({super.key, required this.member});

  @override
  State<GrowthTrackingScreen> createState() => _GrowthTrackingScreenState();
}

class _GrowthTrackingScreenState extends State<GrowthTrackingScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<dynamic> _vitals = [];
  bool _loading = true;

  /// عمر الطفل بالشهور — مخزَّن دائماً بالشهور في قاعدة البيانات
  int get _ageInMonths => widget.member.age;

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      if (mounted) setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      final filtered =
          vitals.where((v) => v.type == 'height' || v.type == 'weight').toList();
      setState(() {
        _vitals = filtered;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError('تعذّر تحميل بيانات النمو: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(msg, style: const TextStyle(color: Colors.white))));
  }

  /// يعرض حوار تأكيد للتحذيرات التي لا تمنع الحفظ (warning / severe).
  /// يُرجع true إذا أكّد المستخدم الحفظ، false إذا اختار التصحيح.
  Future<bool> _confirmWarning(GrowthValidationResult result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(result.icon, color: result.color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              result.level == GrowthValidationLevel.severe
                  ? 'تحذير شديد'
                  : 'تنبيه',
              style: TextStyle(
                  fontSize: 16,
                  color: result.color,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        content: Text(
          '${result.message}\n\nهل تريد الحفظ على أي حال؟',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تصحيح القيمة'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: result.color),
            child: const Text('حفظ على أي حال',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showAddDialog() {
    final hCtrl = TextEditingController();
    final wCtrl = TextEditingController();

    final ageM   = _ageInMonths;
    final wRange = whoWeightRange(ageM);
    final hRange = whoHeightRange(ageM);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل بيانات النمو',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المعدل الطبيعي — ${wRange['label']}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الوزن: ${wRange['min']} – ${wRange['max']} كجم'
                    '   |   '
                    'الطول: ${hRange['min']} – ${hRange['max']} سم',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grey600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: hCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'الطول (سم)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon:
                    const Icon(Icons.straighten, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'الوزن (كجم)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.scale, color: AppColors.teal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final hVal = double.tryParse(hCtrl.text.trim());
              final wVal = double.tryParse(wCtrl.text.trim());

              if (hVal == null && wVal == null) {
                _showError('أدخل قيمة واحدة على الأقل');
                return;
              }

              // ── مرحلة 1: تحقق من كل قياس على حدة ─────────────────────────
              if (hVal != null) {
                final r =
                    validateSingleMeasurement('height', hVal, _ageInMonths);
                if (r.blocksSubmit) {
                  _showError(r.message);
                  return;
                }
                if (r.level != GrowthValidationLevel.ok) {
                  final proceed = await _confirmWarning(r);
                  if (!proceed) return;
                }
              }
              if (wVal != null) {
                final r =
                    validateSingleMeasurement('weight', wVal, _ageInMonths);
                if (r.blocksSubmit) {
                  _showError(r.message);
                  return;
                }
                if (r.level != GrowthValidationLevel.ok) {
                  final proceed = await _confirmWarning(r);
                  if (!proceed) return;
                }
              }

              // ── مرحلة 2: تحقق من اتساق الطول مع الوزن معاً ────────────────
              if (hVal != null && wVal != null) {
                final r = validateHeightWeightConsistency(
                    hVal, wVal, _ageInMonths);
                if (r != null) {
                  if (r.blocksSubmit) {
                    _showError(r.message);
                    return;
                  }
                  final proceed = await _confirmWarning(r);
                  if (!proceed) return;
                }
              }

              // ── مرحلة 3: الحفظ ─────────────────────────────────────────────
              final nav = Navigator.of(ctx);
              try {
                final familyId = await _authService.familyId;
                if (!mounted || familyId == null) return;

                if (hVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId,
                    memberId: widget.member.id!,
                    type: 'height',
                    value: hVal,
                    unit: 'سم',
                  ));
                }
                if (wVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId,
                    memberId: widget.member.id!,
                    type: 'weight',
                    value: wVal,
                    unit: 'كجم',
                  ));
                }
                nav.pop();
                _loadVitals();
              } catch (e) {
                _showError('تعذّر الحفظ: $e');
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildWhoReferenceCard() {
    final ageM   = _ageInMonths;
    final wRange = whoWeightRange(ageM);
    final hRange = whoHeightRange(ageM);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.9),
            const Color(0xFF004D40)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.health_and_safety_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            // formattedAge handles months vs years for children
            Text(
              'معايير منظمة الصحة العالمية — ${widget.member.formattedAge}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _WhoRangeChip(
              icon: Icons.scale_rounded,
              label: 'الوزن',
              range: '${wRange['min']} – ${wRange['max']} كجم',
            )),
            const SizedBox(width: 10),
            Expanded(child: _WhoRangeChip(
              icon: Icons.straighten_rounded,
              label: 'الطول',
              range: '${hRange['min']} – ${hRange['max']} سم',
            )),
          ]),
          const SizedBox(height: 8),
          Text('الفئة العمرية: ${wRange['label']}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('تتبع النمو')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                // ── رأس ملف الطفل — يستخدم formattedAge ──────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: t.bgColor,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(t.icon, color: t.color),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.member.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            // formattedAge: "36 شهراً" → "3 سنة"
                            Text(
                              widget.member.formattedAge,
                              style: const TextStyle(
                                  color: AppColors.grey600, fontSize: 13),
                            ),
                          ]),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),

                SliverToBoxAdapter(child: _buildWhoReferenceCard()),

                if (_vitals.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                          child: Column(children: [
                        Icon(Icons.show_chart_rounded,
                            size: 64, color: AppColors.grey200),
                        const SizedBox(height: 16),
                        const Text('لا توجد سجلات نمو بعد',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey600)),
                        const SizedBox(height: 8),
                        const Text('اضغط + لتسجيل الطول والوزن',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.grey500)),
                      ])),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList.separated(
                      itemCount: _vitals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final vital    = _vitals[index];
                        final isHeight = vital.type == 'height';
                        final feedback = getWhoFeedback(
                          type: vital.type,
                          value: vital.value,
                          ageInMonths: _ageInMonths,
                        );
                        final range = isHeight
                            ? whoHeightRange(_ageInMonths)
                            : whoWeightRange(_ageInMonths);
                        final Color statusColor = feedback['color'] as Color;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color:
                                        statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isHeight
                                        ? Icons.straighten_rounded
                                        : Icons.scale_rounded,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(isHeight ? 'الطول' : 'الوزن',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.grey900)),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                              alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                            feedback['msg'] as String,
                                            style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ]),
                                  ],
                                )),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${vital.value} ${vital.unit}',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor),
                                      ),
                                      Text(
                                        vital.recordedAt
                                                ?.toString()
                                                .split('T')
                                                .first ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.grey500),
                                      ),
                                    ]),
                              ]),
                              const SizedBox(height: 10),
                              _WhoRangeBar(
                                value: vital.value,
                                min: (range['min'] as num).toDouble(),
                                max: (range['max'] as num).toDouble(),
                                color: statusColor,
                                unit: isHeight ? 'سم' : 'كجم',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تسجيل النمو'),
      ),
    );
  }
}

// ── ويدجت نطاق WHO (Chip صغير) ───────────────────────────────────────────────
class _WhoRangeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String range;
  const _WhoRangeChip(
      {required this.icon, required this.label, required this.range});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 10)),
              Text(range,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ])),
      ]),
    );
  }
}

// ── شريط النطاق البصري ────────────────────────────────────────────────────────
class _WhoRangeBar extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Color color;
  final String unit;

  const _WhoRangeBar({
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final double rangeSpan   = (max - min) * 1.4;
    final double barMin      = min - rangeSpan * 0.2;
    final double barMax      = max + rangeSpan * 0.2;
    final double position    = ((value - barMin) / (barMax - barMin)).clamp(0.0, 1.0);
    final double normalStart = ((min - barMin) / (barMax - barMin)).clamp(0.0, 1.0);
    final double normalEnd   = ((max - barMin) / (barMax - barMin)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$min $unit',
              style:
                  const TextStyle(fontSize: 10, color: AppColors.grey500)),
          const Text('النطاق الطبيعي',
              style: TextStyle(fontSize: 10, color: AppColors.grey500)),
          Text('$max $unit',
              style:
                  const TextStyle(fontSize: 10, color: AppColors.grey500)),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(clipBehavior: Clip.none, children: [
            Container(
                height: 6,
                decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(3))),
            Positioned(
              left: w * normalStart,
              width: w * (normalEnd - normalStart),
              top: 0,
              child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3))),
            ),
            Positioned(
              left: (w * position - 5).clamp(0.0, w - 10),
              top: -3,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4), blurRadius: 4)
                  ],
                ),
              ),
            ),
          ]);
        }),
      ],
    );
  }
}