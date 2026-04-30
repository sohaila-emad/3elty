import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_repository.dart';
import '../main.dart';

// ─── خدمة إنشاء التقارير الطبية بصيغة PDF ────────────────────────────────────
//
// تنشئ تقريراً شاملاً يتضمن:
//   • رأس الصفحة  : اسم الفرد، العمر، نوع الملف
//   • الأدوية     : قائمة كاملة بالجرعات وأوقات الأخذ
//   • العلامات الحيوية: آخر 10 قراءات مع المقارنة بالنطاق الطبيعي
//   • الوثائق     : أسماء آخر 10 وثائق مرفوعة
//
// دعم العربية: يُستخدم خط Amiri (مُضمَّن في assets/fonts/Amiri-Regular.ttf)
// ──────────────────────────────────────────────────────────────────────────────

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();
  factory ReportService() => instance;

  final _repo = AppRepository.instance;

  // Normal ranges for vitals — mirrors VitalsScreen._normalRanges
  static const Map<String, Map<String, double>> _normalRanges = {
    'ضغط الدم (الانقباضي)': {'min': 90,   'max': 120},
    'ضغط الدم (الانبساطي)': {'min': 60,   'max': 80},
    'سكر الدم':              {'min': 70,   'max': 140},
    'معدل ضربات القلب':      {'min': 60,   'max': 100},
    'درجة الحرارة':          {'min': 36.1, 'max': 37.2},
  };

  static const Map<String, String> _units = {
    'ضغط الدم (الانقباضي)': 'mmHg',
    'ضغط الدم (الانبساطي)': 'mmHg',
    'سكر الدم':              'mg/dL',
    'معدل ضربات القلب':      'bpm',
    'درجة الحرارة':          '°C',
  };

  // ── Public: generate and open share/print dialog ──────────────────────────
  Future<void> generateAndShare({
    required FamilyMember member,
    required String memberId,
  }) async {
    final pdfBytes = await _buildPdf(member: member, memberId: memberId);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'تقرير_${member.name}_${_today()}.pdf',
    );
  }

  // ── Build the PDF document ────────────────────────────────────────────────
  Future<Uint8List> _buildPdf({
    required FamilyMember member,
    required String memberId,
  }) async {
    // Load Amiri font
    pw.Font amiri;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      amiri = pw.Font.ttf(fontData);
    } catch (_) {
      // Fallback: use pdf package's Helvetica (Latin only) if font is missing
      amiri = pw.Font.helvetica();
    }

    final ttf = pw.TextStyle(font: amiri);

    // Fetch data concurrently
    final results = await Future.wait([
      _repo.getMedicationsForMember(memberId),
      _repo.getVitalsForMember(memberId, limit: 10),
      _repo.getDocumentsForMember(memberId),
    ]);

    final medications = results[0] as List<MedicationRecord>;
    final vitals      = results[1] as List<VitalRecord>;
    final documents   = results[2] as List<DocumentRecord>;

    // Design palette
    const headerColor    = PdfColor.fromInt(0xFF00796B); // teal
    const sectionColor   = PdfColor.fromInt(0xFFE0F2F1); // teal light
    const textDark       = PdfColor.fromInt(0xFF212121);
    const textGrey       = PdfColor.fromInt(0xFF757575);
    const borderColor    = PdfColor.fromInt(0xFFEEEEEE);
    const normalGreen    = PdfColor.fromInt(0xFF2E7D32);
    const warnRed        = PdfColor.fromInt(0xFFD32F2F);
    const warnBlue       = PdfColor.fromInt(0xFF1565C0);

    // ── Helpers ──────────────────────────────────────────────────────────────
    pw.TextStyle body(double size, {PdfColor? color, bool bold = false}) =>
        ttf.copyWith(fontSize: size, color: color ?? textDark,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);

    pw.Widget sectionHeader(String title) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const pw.BoxDecoration(color: sectionColor),
      child: pw.Text(title, textDirection: pw.TextDirection.rtl,
          style: body(13, bold: true, color: PdfColor.fromInt(0xFF00796B))),
    );

    pw.Widget divider() => pw.Container(height: 1, color: borderColor,
        margin: const pw.EdgeInsets.symmetric(vertical: 4));

    String vitalStatus(VitalRecord v) {
      final r = _normalRanges[v.type];
      if (r == null) return '—';
      if (v.value < r['min']!) return 'أقل من الطبيعي';
      if (v.value > r['max']!) return 'أعلى من الطبيعي';
      return 'ضمن الطبيعي';
    }

    PdfColor vitalColor(VitalRecord v) {
      final r = _normalRanges[v.type];
      if (r == null) return textGrey;
      if (v.value < r['min']!) return warnBlue;
      if (v.value > r['max']!) return warnRed;
      return normalGreen;
    }

    // ── Build the document ────────────────────────────────────────────────
    final doc = pw.Document(
      title: 'تقرير صحي — ${member.name}',
      author: 'تطبيق عيلتي',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [

          // ══ الرأس ══════════════════════════════════════════════════════════
          pw.Container(
            decoration: const pw.BoxDecoration(
              color: headerColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('تقرير صحي شامل',
                        textDirection: pw.TextDirection.rtl,
                        style: body(10, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text(member.name,
                        textDirection: pw.TextDirection.rtl,
                        style: body(20, bold: true, color: PdfColors.white)),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      _chip(member.profileType.label, amiri),
                      pw.SizedBox(width: 8),
                      _chip(formatMemberAge(member), amiri),
                    ]),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('تاريخ التقرير', textDirection: pw.TextDirection.rtl,
                        style: body(9, color: PdfColors.white)),
                    pw.Text(_today(), textDirection: pw.TextDirection.rtl,
                        style: body(11, color: PdfColors.white, bold: true)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ══ الأدوية ════════════════════════════════════════════════════════
          sectionHeader('💊  الأدوية النشطة'),
          pw.SizedBox(height: 6),

          if (medications.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('لا توجد أدوية مسجَّلة.',
                  textDirection: pw.TextDirection.rtl,
                  style: body(11, color: textGrey)),
            )
          else
            pw.TableHelper.fromTextArray(
              context: ctx,
              data: [
                ['وقت الأخذ', 'التكرار', 'الجرعة', 'اسم الدواء'],
                ...medications.map((m) => [m.timeOfDay, m.frequency, m.dose, m.name]),
              ],
              headers: ['وقت الأخذ', 'التكرار', 'الجرعة', 'اسم الدواء'],
              cellStyle: pw.TextStyle(font: amiri, fontSize: 10),
              headerStyle: pw.TextStyle(font: amiri, fontSize: 10, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: sectionColor),
              border: pw.TableBorder.all(color: borderColor, width: 0.5),
              cellHeight: 24,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
            ),

          pw.SizedBox(height: 16),

          // ══ العلامات الحيوية ═══════════════════════════════════════════════
          sectionHeader('❤️  العلامات الحيوية — آخر 10 قراءات'),
          pw.SizedBox(height: 6),

          if (vitals.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('لا توجد قراءات مسجَّلة.',
                  textDirection: pw.TextDirection.rtl,
                  style: body(11, color: textGrey)),
            )
          else
            ...vitals.map((v) {
              final status = vitalStatus(v);
              final color  = vitalColor(v);
              final unit   = _units[v.type] ?? '';
              final range  = _normalRanges[v.type];
              final rangeText = range != null
                  ? 'الطبيعي: ${range['min']} – ${range['max']} $unit'
                  : '';
              return pw.Column(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Right side: name + date
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(v.type, textDirection: pw.TextDirection.rtl,
                              style: body(11, bold: true)),
                          pw.Text(
                            v.recordedAt.length >= 10
                                ? v.recordedAt.substring(0, 10)
                                : v.recordedAt,
                            textDirection: pw.TextDirection.rtl,
                            style: body(9, color: textGrey),
                          ),
                          if (rangeText.isNotEmpty)
                            pw.Text(rangeText, textDirection: pw.TextDirection.rtl,
                                style: body(8, color: textGrey)),
                        ],
                      ),
                      // Left side: value + status badge
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('${v.value} $unit',
                              textDirection: pw.TextDirection.rtl,
                              style: body(14, bold: true, color: color)),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: color.shade(0.85),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(status,
                                textDirection: pw.TextDirection.rtl,
                                style: body(8, color: color, bold: true)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
              ]);
            }),

          pw.SizedBox(height: 16),

          // ══ الوثائق ════════════════════════════════════════════════════════
          sectionHeader('📁  الوثائق الطبية'),
          pw.SizedBox(height: 6),

          if (documents.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('لا توجد وثائق مرفوعة.',
                  textDirection: pw.TextDirection.rtl,
                  style: body(11, color: textGrey)),
            )
          else
            ...documents.take(10).map((d) => pw.Column(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 0.5))),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(d.title,
                            textDirection: pw.TextDirection.rtl,
                            style: body(11, bold: true)),
                        pw.Row(children: [
                          pw.Text(d.docType,
                              textDirection: pw.TextDirection.rtl,
                              style: body(9, color: textGrey)),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            d.createdAt.length >= 10
                                ? d.createdAt.substring(0, 10)
                                : d.createdAt,
                            textDirection: pw.TextDirection.rtl,
                            style: body(9, color: textGrey),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ])),

          pw.SizedBox(height: 24),
          divider(),

          // ══ Footer ═════════════════════════════════════════════════════════
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تطبيق عيلتي — للمعلومات فقط، لا يُغني عن الاستشارة الطبية',
                  textDirection: pw.TextDirection.rtl,
                  style: body(8, color: textGrey)),
              pw.Text(_today(),
                  textDirection: pw.TextDirection.rtl,
                  style: body(8, color: textGrey)),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  pw.Widget _chip(String text, pw.Font font) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        ),
        child: pw.Text(text,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
                font: font, fontSize: 10, color: PdfColors.white)),
      );

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}