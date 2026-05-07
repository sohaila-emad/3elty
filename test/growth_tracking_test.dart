// ============================================================
//  FILE: test/unit/growth_tracking_test.dart
//  WHAT IT TESTS: lib/modules/growth_tracking_screen.dart
//  COVERS:
//    • whoWeightRange()      — WHO weight lookup table
//    • whoHeightRange()      — WHO height lookup table
//    • getWhoFeedback()      — status classification (ok/low/high)
//    • validateGrowthEntry() — age-aware input validation
//
//  TYPE: Unit Test  (pure functions — zero mocks, zero Firebase)
//  RUN: flutter test test/unit/growth_tracking_test.dart
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

// ← These 4 functions are top-level (outside any class) in growth_tracking_screen.dart
//   so they can be imported directly — no widget or Firebase needed.
import 'package:flutter_application_1/modules/growth_tracking_screen.dart';
void main() {
  // ─────────────────────────────────────────────────────────
  //  GROUP 1 — whoWeightRange()
  //  Makes sure the right WHO weight band is returned for
  //  each key age milestone.
  // ─────────────────────────────────────────────────────────
  group('whoWeightRange()', () {

    test('UT-GR-01 | newborn (0 months) → range 2.9–5.1 kg', () {
      final result = whoWeightRange(0);
      // A newborn's normal weight per WHO is 2.9 to 5.1 kg
      expect(result['min'], equals(2.9));
      expect(result['max'], equals(5.1));
    });

    test('UT-GR-02 | 1 month old → still in newborn band (≤ 1)', () {
      final result = whoWeightRange(1);
      expect(result['min'], equals(2.9));
      expect(result['max'], equals(5.1));
    });

    test('UT-GR-03 | 6 months old → range 5.7–9.2 kg', () {
      final result = whoWeightRange(6);
      expect(result['min'], equals(5.7));
      expect(result['max'], equals(9.2));
    });

    test('UT-GR-04 | 12 months old → range 7.7–11.9 kg', () {
      final result = whoWeightRange(12);
      expect(result['min'], equals(7.7));
      expect(result['max'], equals(11.9));
    });

    test('UT-GR-05 | 24 months old → range 9.7–15.3 kg', () {
      final result = whoWeightRange(24);
      expect(result['min'], equals(9.7));
      expect(result['max'], equals(15.3));
    });

    test('UT-GR-06 | 60 months (5 years) → range 14.1–24.2 kg', () {
      final result = whoWeightRange(60);
      expect(result['min'], equals(14.1));
      expect(result['max'], equals(24.2));
    });

    test('UT-GR-07 | 120 months (10 years) → range 24.0–46.9 kg', () {
      final result = whoWeightRange(120);
      expect(result['min'], equals(24.0));
      expect(result['max'], equals(46.9));
    });

    test('UT-GR-08 | result always contains min, max, and label keys', () {
      // Test multiple ages to make sure the map structure is always correct
      for (final age in [0, 3, 6, 12, 24, 36, 60, 84, 120, 144, 180]) {
        final result = whoWeightRange(age);
        expect(result.containsKey('min'),   isTrue,  reason: 'Missing min at age=$age');
        expect(result.containsKey('max'),   isTrue,  reason: 'Missing max at age=$age');
        expect(result.containsKey('label'), isTrue,  reason: 'Missing label at age=$age');
        expect(result['min'], lessThan(result['max']), reason: 'min >= max at age=$age');
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  //  GROUP 2 — whoHeightRange()
  // ─────────────────────────────────────────────────────────
  group('whoHeightRange()', () {

    test('UT-GR-09 | newborn (0 months) → range 48.0–55.6 cm', () {
      final result = whoHeightRange(0);
      expect(result['min'], equals(48.0));
      expect(result['max'], equals(55.6));
    });

    test('UT-GR-10 | 6 months → range 61.2–70.3 cm', () {
      final result = whoHeightRange(6);
      expect(result['min'], equals(61.2));
      expect(result['max'], equals(70.3));
    });

    test('UT-GR-11 | 12 months → range 70.1–80.5 cm', () {
      final result = whoHeightRange(12);
      expect(result['min'], equals(70.1));
      expect(result['max'], equals(80.5));
    });

    test('UT-GR-12 | 24 months → range 81.7–93.9 cm', () {
      final result = whoHeightRange(24);
      expect(result['min'], equals(81.7));
      expect(result['max'], equals(93.9));
    });

    test('UT-GR-13 | 60 months (5 years) → range 100.7–118.9 cm', () {
      final result = whoHeightRange(60);
      expect(result['min'], equals(100.7));
      expect(result['max'], equals(118.9));
    });

    test('UT-GR-14 | 144 months (12 years) → range 134.5–159.5 cm', () {
      final result = whoHeightRange(144);
      expect(result['min'], equals(134.5));
      expect(result['max'], equals(159.5));
    });

    test('UT-GR-15 | height range always increases with age (growth check)', () {
      // An older child should always have a higher minimum height than a younger one
      final ages = [0, 6, 12, 24, 36, 60, 84, 120, 144, 168];
      for (int i = 1; i < ages.length; i++) {
        final prev = whoHeightRange(ages[i - 1]);
        final curr = whoHeightRange(ages[i]);
        expect(
          (curr['min'] as double) > (prev['min'] as double),
          isTrue,
          reason: 'Height min did NOT increase between age ${ages[i-1]} and ${ages[i]}',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  //  GROUP 3 — getWhoFeedback()  (WEIGHT)
  //  Tests the classification logic:
  //    < min*0.85  → severe underweight  (status: 'low')
  //    < min       → below normal        (status: 'low')
  //    in range    → normal              (status: 'ok')
  //    > max       → above normal        (status: 'high')
  //    > max*1.15  → clearly overweight  (status: 'high')
  // ─────────────────────────────────────────────────────────
  group('getWhoFeedback() — weight', () {
    // For a 12-month-old: WHO weight range is 7.7–11.9 kg
    //   Severe low threshold  = 7.7 * 0.85 = 6.545 kg
    //   Clearly high threshold = 11.9 * 1.15 = 13.685 kg

    test('UT-GR-16 | weight within normal range → status ok', () {
      final result = getWhoFeedback(type: 'weight', value: 9.5, ageInMonths: 12);
      expect(result['status'], equals('ok'));
    });

    test('UT-GR-17 | weight at exact min boundary → status ok', () {
      final result = getWhoFeedback(type: 'weight', value: 7.7, ageInMonths: 12);
      expect(result['status'], equals('ok'));
    });

    test('UT-GR-18 | weight slightly below min → status low (below normal)', () {
      // 7.5 < 7.7 (min) but > 7.7*0.85=6.545 → below normal, not severe
      final result = getWhoFeedback(type: 'weight', value: 7.5, ageInMonths: 12);
      expect(result['status'], equals('low'));
    });

    test('UT-GR-19 | weight severely low (< min * 0.85) → status low, severe', () {
      // 6.0 < 6.545 (min*0.85) → severe underweight
      final result = getWhoFeedback(type: 'weight', value: 6.0, ageInMonths: 12);
      expect(result['status'], equals('low'));
      // The message should indicate severity
      expect(result['msg'], contains('حاد'));
    });

    test('UT-GR-20 | weight above max → status high', () {
      // 12.5 > 11.9 (max) → above normal
      final result = getWhoFeedback(type: 'weight', value: 12.5, ageInMonths: 12);
      expect(result['status'], equals('high'));
    });

    test('UT-GR-21 | weight clearly above max (> max * 1.15) → status high, clearly overweight', () {
      // 14.0 > 13.685 (max*1.15) → clearly overweight
      final result = getWhoFeedback(type: 'weight', value: 14.0, ageInMonths: 12);
      expect(result['status'], equals('high'));
      expect(result['msg'], contains('واضح'));
    });

    test('UT-GR-22 | feedback map always contains msg, color, status keys', () {
      final result = getWhoFeedback(type: 'weight', value: 9.0, ageInMonths: 12);
      expect(result.containsKey('msg'),    isTrue);
      expect(result.containsKey('color'),  isTrue);
      expect(result.containsKey('status'), isTrue);
      // color must be a real Flutter Color object
      expect(result['color'], isA<Color>());
    });
  });

  // ─────────────────────────────────────────────────────────
  //  GROUP 4 — getWhoFeedback()  (HEIGHT)
  //  For a 12-month-old: WHO height range is 70.1–80.5 cm
  //    Severe short: < 70.1 * 0.93 = 65.19 cm
  //    Notably tall: > 80.5 * 1.07 = 86.14 cm
  // ─────────────────────────────────────────────────────────
  group('getWhoFeedback() — height', () {

    test('UT-GR-23 | height within normal range → status ok', () {
      final result = getWhoFeedback(type: 'height', value: 75.0, ageInMonths: 12);
      expect(result['status'], equals('ok'));
    });

    test('UT-GR-24 | height slightly below min → status low', () {
      // 69.0 < 70.1 (min) but > 65.19 (min*0.93) → below average, not severe
      final result = getWhoFeedback(type: 'height', value: 69.0, ageInMonths: 12);
      expect(result['status'], equals('low'));
    });

    test('UT-GR-25 | height severely short (< min * 0.93) → status low, severe', () {
      // 64.0 < 65.19 (min*0.93) → notable growth delay
      final result = getWhoFeedback(type: 'height', value: 64.0, ageInMonths: 12);
      expect(result['status'], equals('low'));
      expect(result['msg'], contains('ملحوظ'));
    });

    test('UT-GR-26 | height above max → status high', () {
      final result = getWhoFeedback(type: 'height', value: 82.0, ageInMonths: 12);
      expect(result['status'], equals('high'));
    });

    test('UT-GR-27 | height notably above max (> max * 1.07) → status high', () {
      // 87.0 > 86.14 (max*1.07)
      final result = getWhoFeedback(type: 'height', value: 87.0, ageInMonths: 12);
      expect(result['status'], equals('high'));
    });
  });

  // ─────────────────────────────────────────────────────────
  //  GROUP 5 — validateGrowthEntry()
  //  Tests the age-context validation for height and weight.
  //  Returns null = valid input, non-null string = error message.
  // ─────────────────────────────────────────────────────────
  group('validateGrowthEntry()', () {

    // ── HEIGHT ──────────────────────────────────────────
    test('UT-GR-28 | valid height for 12-month-old (80 cm) → no error', () {
      final result = validateGrowthEntry('height', 80.0, 12);
      expect(result, isNull);
    });

    test('UT-GR-29 | height > 65 cm for infant < 3 months → error', () {
      // A 2-month-old cannot be 70 cm tall — out of range for that age
      final result = validateGrowthEntry('height', 70.0, 2);
      expect(result, isNotNull);
      expect(result, contains('65'));
    });

    test('UT-GR-30 | height > 90 cm for infant < 12 months → error', () {
      final result = validateGrowthEntry('height', 95.0, 10);
      expect(result, isNotNull);
      expect(result, contains('90'));
    });

    test('UT-GR-31 | height > 115 cm for child < 36 months → error', () {
      final result = validateGrowthEntry('height', 120.0, 24);
      expect(result, isNotNull);
    });

    test('UT-GR-32 | height below 20 cm (impossible) → error', () {
      final result = validateGrowthEntry('height', 15.0, 24);
      expect(result, isNotNull);
      expect(result, contains('20'));
    });

    test('UT-GR-33 | height above 220 cm (impossible) → error', () {
      final result = validateGrowthEntry('height', 230.0, 120);
      expect(result, isNotNull);
      expect(result, contains('220'));
    });

    test('UT-GR-34 | height exactly 20 cm (boundary) → no error', () {
      // 20 is the lower bound — should pass
      final result = validateGrowthEntry('height', 20.0, 36);
      expect(result, isNull);
    });

    test('UT-GR-35 | height exactly 220 cm (boundary) → no error', () {
      final result = validateGrowthEntry('height', 220.0, 216); // 18 years
      expect(result, isNull);
    });

    // ── WEIGHT ──────────────────────────────────────────
    test('UT-GR-36 | valid weight for 12-month-old (9 kg) → no error', () {
      final result = validateGrowthEntry('weight', 9.0, 12);
      expect(result, isNull);
    });

    test('UT-GR-37 | weight > 12 kg for infant < 6 months → error', () {
      // An infant under 6 months should not weigh more than 12 kg
      final result = validateGrowthEntry('weight', 13.0, 4);
      expect(result, isNotNull);
      expect(result, contains('12'));
    });

    test('UT-GR-38 | weight > 16 kg for infant < 12 months → error', () {
      final result = validateGrowthEntry('weight', 17.0, 10);
      expect(result, isNotNull);
      expect(result, contains('16'));
    });

    test('UT-GR-39 | weight below 0.5 kg (impossible) → error', () {
      final result = validateGrowthEntry('weight', 0.3, 12);
      expect(result, isNotNull);
      expect(result, contains('0.5'));
    });

    test('UT-GR-40 | weight above 200 kg (impossible) → error', () {
      final result = validateGrowthEntry('weight', 205.0, 120);
      expect(result, isNotNull);
      expect(result, contains('200'));
    });

    test('UT-GR-41 | weight exactly 0.5 kg (lower boundary) → no error', () {
      final result = validateGrowthEntry('weight', 0.5, 0);
      expect(result, isNull);
    });

    test('UT-GR-42 | valid height for a 5-year-old (110 cm) → no error', () {
      final result = validateGrowthEntry('height', 110.0, 60);
      expect(result, isNull);
    });

    test('UT-GR-43 | valid weight for a 10-year-old (32 kg) → no error', () {
      final result = validateGrowthEntry('weight', 32.0, 120);
      expect(result, isNull);
    });
  });
}
