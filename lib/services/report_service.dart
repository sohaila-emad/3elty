import 'dart:math';
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
//   • رأس الصفحة       : شعار التطبيق، اسم الفرد، التاريخ، رقم العضوية
//   • بيانات المريض    : الاسم، نوع الملف، العمر، رقم العضوية في شبكة منظمة
//   • العلامات الحيوية : آخر 3 قراءات في جدول + رسم بياني بسيط
//   • الأدوية          : جدول احترافي بالاسم والجرعة والتكرار
//   • التذييل          : نص الخصوصية والتشفير
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
    'ضغط الدم (الانقباضي)': {'min': 90, 'max': 120},
    'ضغط الدم (الانبساطي)': {'min': 60, 'max': 80},
    'سكر الدم': {'min': 70, 'max': 140},
    'معدل ضربات القلب': {'min': 60, 'max': 100},
    'درجة الحرارة': {'min': 36.1, 'max': 37.2},
  };

  static const Map<String, String> _units = {
    'ضغط الدم (الانقباضي)': 'mmHg',
    'ضغط الدم (الانبساطي)': 'mmHg',
    'سكر الدم': 'mg/dL',
    'معدل ضربات القلب': 'bpm',
    'درجة الحرارة': '°C',
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
    // Load Amiri font for Arabic support
    pw.Font amiri;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      amiri = pw.Font.ttf(fontData);
    } catch (_) {
      amiri = pw.Font.helvetica();
    }

    // Fetch data concurrently
    final results = await Future.wait([
      _repo.getMedicationsForMember(memberId),
      _repo.getVitalsForMember(memberId, limit: 10),
      _repo.getDocumentsForMember(memberId),
    ]);

    final medications = results[0] as List<MedicationRecord>;
    final allVitals = results[1] as List<VitalRecord>;
    final documents = results[2] as List<DocumentRecord>;

    // Only last 3 vitals for the table
    final vitals = allVitals.take(3).toList();

    // ── Design palette ────────────────────────────────────────────────────
    const teal = PdfColor.fromInt(0xFF00796B);
    const tealDark = PdfColor.fromInt(0xFF004D40);
    const tealLight = PdfColor.fromInt(0xFFE0F2F1);
    const tealMid = PdfColor.fromInt(0xFF80CBC4);
    const textDark = PdfColor.fromInt(0xFF212121);
    const textGrey = PdfColor.fromInt(0xFF757575);
    const textLight = PdfColor.fromInt(0xFFBDBDBD);
    const borderColor = PdfColor.fromInt(0xFFE0E0E0);
    const normalGreen = PdfColor.fromInt(0xFF2E7D32);
    const warnRed = PdfColor.fromInt(0xFFD32F2F);
    const warnBlue = PdfColor.fromInt(0xFF1565C0);
    const white = PdfColors.white;
    const bgPage = PdfColor.fromInt(0xFFFAFAFA);
    const cardBg = PdfColors.white;

    // Generate a deterministic membership number from memberId
    final memberNum = _membershipNumber(memberId);

    // ── Text style helpers ────────────────────────────────────────────────
    pw.TextStyle ts(
      double size, {
      PdfColor? color,
      bool bold = false,
      bool italic = false,
    }) =>
        pw.TextStyle(
          font: amiri,
          fontSize: size,
          color: color ?? textDark,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
        );

    // ── RTL text widget ───────────────────────────────────────────────────
    pw.Widget rtl(
      String text,
      pw.TextStyle style, {
      pw.TextAlign align = pw.TextAlign.right,
    }) =>
        pw.Text(text,
            textDirection: pw.TextDirection.rtl,
            textAlign: align,
            style: style);

    // ── Card container ────────────────────────────────────────────────────
    pw.Widget card({
      required pw.Widget child,
      pw.EdgeInsets padding =
          const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      PdfColor? border,
    }) =>
        pw.Container(
          width: double.infinity,
          padding: padding,
          decoration: pw.BoxDecoration(
            color: cardBg,
            border: pw.Border.all(color: border ?? borderColor, width: 0.6),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: child,
        );

    // ── Section header ────────────────────────────────────────────────────
    pw.Widget sectionHeader(String title, {String? subtitle}) =>
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: tealLight,
              border: pw.Border(
                right: pw.BorderSide(color: teal, width: 4),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (subtitle != null)
                  rtl(subtitle, ts(8.5, color: textGrey)),
                rtl(title, ts(12.5, bold: true, color: tealDark)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ]);

    // ── Thin divider ──────────────────────────────────────────────────────
    pw.Widget divider({double v = 12}) => pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: v),
          child: pw.Container(height: 0.5, color: borderColor),
        );

    // ── Status badge ──────────────────────────────────────────────────────
    PdfColor _vitalColor(VitalRecord v) {
      final r = _normalRanges[v.type];
      if (r == null) return textGrey;
      if (v.value < r['min']!) return warnBlue;
      if (v.value > r['max']!) return warnRed;
      return normalGreen;
    }

    String _vitalStatus(VitalRecord v) {
      final r = _normalRanges[v.type];
      if (r == null) return '—';
      if (v.value < r['min']!) return 'أقل من الطبيعي';
      if (v.value > r['max']!) return 'أعلى من الطبيعي';
      return 'ضمن الطبيعي';
    }

    pw.Widget statusBadge(String label, PdfColor color) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: pw.BoxDecoration(
            color: color == normalGreen
                ? const PdfColor.fromInt(0xFFE8F5E9)
                : color == warnRed
                    ? const PdfColor.fromInt(0xFFFFEBEE)
                    : const PdfColor.fromInt(0xFFE3F2FD),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            border: pw.Border.all(color: color, width: 0.5),
          ),
          child: rtl(label, ts(7.5, color: color, bold: true)),
        );

    // ── Vitals sparkline chart (pw.CustomPaint) ───────────────────────────
    // Groups vitals by type, draws last-N readings as a line+dot chart
    pw.Widget _buildVitalsChart(List<VitalRecord> records) {
      if (records.isEmpty) return pw.SizedBox();

      // Group by type
      final Map<String, List<VitalRecord>> byType = {};
      for (final v in records) {
        byType.putIfAbsent(v.type, () => []).add(v);
      }

      const chartW = 480.0;
      const chartH = 90.0;
      const padL = 8.0;
      const padR = 8.0;
      const padT = 10.0;
      const padB = 18.0;

      // Pick up to 3 vital types with enough data
      final typeEntries = byType.entries
          .where((e) => e.value.length >= 2)
          .take(3)
          .toList();

      if (typeEntries.isEmpty) return pw.SizedBox();

      final colors = [teal, const PdfColor.fromInt(0xFF7B1FA2), warnRed];

      return card(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            rtl('مخطط الاتجاه — العلامات الحيوية', ts(10, bold: true, color: teal)),
            pw.SizedBox(height: 8),
            pw.CustomPaint(
              size: const PdfPoint(chartW, chartH + padT + padB),
              painter: (canvas, size) {
                // ── Background rect ──────────────────────────────────────
                // drawRect(x, y, width, height) — all raw doubles
                canvas.setFillColor(const PdfColor.fromInt(0xFFF5F5F5));
                canvas.drawRect(0, 0, size.x, size.y);
                canvas.fillPath();

                // ── Horizontal grid lines ────────────────────────────────
                // Grid spans from padB (bottom of plot) to padB+chartH (top)
                canvas.setStrokeColor(borderColor);
                canvas.setLineWidth(0.3);
                for (int i = 0; i <= 4; i++) {
                  final gy = padB + (chartH / 4) * i;
                  canvas.moveTo(padL, gy);
                  canvas.lineTo(size.x - padR, gy);
                  canvas.strokePath();
                }

                // ── Series lines + dots ──────────────────────────────────
                for (int ti = 0; ti < typeEntries.length; ti++) {
                  final entry = typeEntries[ti];
                  final vals = entry.value.take(6).toList().reversed.toList();
                  final color = colors[ti % colors.length];

                  final minV = vals.map((v) => v.value).reduce(min);
                  final maxV = vals.map((v) => v.value).reduce(max);
                  final range =
                      (maxV - minV).abs() < 0.01 ? 1.0 : maxV - minV;

                  final n = vals.length;
                  // Pre-compute plain x/y doubles — no PdfPoint needed.
                  // PDF canvas origin is bottom-left, so y=0 is the BOTTOM
                  // of the page. To make higher data values appear HIGHER
                  // visually, a larger value must map to a LARGER y
                  // (i.e. further from the bottom = closer to the top of
                  // the drawn area). Formula:
                  //   norm ∈ [0,1]  (0 = minV, 1 = maxV)
                  //   y = padB + chartH * (norm * 0.8 + 0.1)
                  // padB is the distance from the canvas bottom edge to the
                  // start of the plot area, so low values sit just above it
                  // and high values reach toward padT from the bottom.
                  final xs = List<double>.generate(
                    n,
                    (i) => padL + (chartW - padL - padR) * i / (n - 1),
                  );
                  final ys = List<double>.generate(n, (i) {
                    final norm = (vals[i].value - minV) / range;
                    // Higher norm → larger y → higher on PDF canvas ✓
                    return padB + chartH * (norm * 0.8 + 0.1);
                  });

                  // Draw connecting line
                  canvas.setStrokeColor(color);
                  canvas.setLineWidth(1.5);
                  canvas.moveTo(xs[0], ys[0]);
                  for (int i = 1; i < n; i++) {
                    canvas.lineTo(xs[i], ys[i]);
                  }
                  canvas.strokePath();

                  // Draw filled dots with white border
                  for (int i = 0; i < n; i++) {
                    const r = 2.5;
                    // Filled circle
                    canvas.setFillColor(color);
                    canvas.drawEllipse(xs[i], ys[i], r, r);
                    canvas.fillPath();
                    // White ring
                    canvas.setStrokeColor(PdfColors.white);
                    canvas.setLineWidth(0.8);
                    canvas.drawEllipse(xs[i], ys[i], r, r);
                    canvas.strokePath();
                  }
                }
              },
            ),
            pw.SizedBox(height: 6),
            // Legend
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: List.generate(typeEntries.length, (ti) {
                final color = colors[ti % colors.length];
                final typeName = typeEntries[ti].key;
                return pw.Row(children: [
                  pw.SizedBox(width: 12),
                  pw.Container(width: 16, height: 2.5, color: color),
                  pw.SizedBox(width: 4),
                  rtl(typeName, ts(7.5, color: textGrey)),
                ]);
              }).reversed.toList(),
            ),
          ],
        ),
      );
    }

    // ── BUILD DOCUMENT ────────────────────────────────────────────────────
    final doc = pw.Document(
      title: 'تقرير صحي — ${member.name}',
      author: 'تطبيق عيلتي',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          textDirection: pw.TextDirection.rtl,
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: bgPage),
          ),
        ),
        header: (ctx) => _buildPageHeader(
          member: member,
          memberNum: memberNum,
          amiri: amiri,
          ts: ts,
          rtl: rtl,
          teal: teal,
          tealDark: tealDark,
          tealMid: tealMid,
          white: white,
          textLight: textLight,
          ctx: ctx,
        ),
        footer: (ctx) => _buildPageFooter(
          amiri: amiri,
          ts: ts,
          rtl: rtl,
          textGrey: textGrey,
          teal: teal,
          borderColor: borderColor,
          ctx: ctx,
        ),
        build: (ctx) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 16, 28, 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ══ Patient Data Section ══════════════════════════════════
                sectionHeader('بيانات المريض'),
                card(
                  child: pw.Column(
                    children: [
                      _infoRow('الاسم الكامل', member.name, ts, rtl,
                          textGrey: textGrey),
                      divider(v: 6),
                      _infoRow(
                          'نوع الملف الصحي', member.profileType.label, ts, rtl,
                          textGrey: textGrey),
                      divider(v: 6),
                      _infoRow('العمر', member.formattedAge, ts, rtl,
                          textGrey: textGrey),
                      divider(v: 6),
                      _infoRow('رقم العضوية', memberNum, ts, rtl,
                          textGrey: textGrey, valueColor: teal),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // ══ Latest Vitals Table ═══════════════════════════════════
                sectionHeader('العلامات الحيوية',
                    subtitle: 'آخر 3 قراءات'),
                if (vitals.isEmpty)
                  card(
                    child: rtl('لا توجد قراءات مسجَّلة.',
                        ts(11, color: textGrey)),
                  )
                else ...[
                  // Table
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor, width: 0.7),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder(
                        horizontalInside:
                            pw.BorderSide(color: borderColor, width: 0.5),
                        verticalInside:
                            pw.BorderSide(color: borderColor, width: 0.5),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2.8), // Date
                        1: const pw.FlexColumnWidth(3.5), // Type
                        2: const pw.FlexColumnWidth(2.2), // Value
                        3: const pw.FlexColumnWidth(2.5), // Status
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: tealLight),
                          children: [
                            _tableCell('التاريخ', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('النوع', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('القيمة', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('الحالة', ts, rtl,
                                isHeader: true, teal: teal),
                          ],
                        ),
                        // Data rows
                        ...vitals.asMap().entries.map((entry) {
                          final i = entry.key;
                          final v = entry.value;
                          final unit = _units[v.type] ?? v.unit;
                          final color = _vitalColor(v);
                          final status = _vitalStatus(v);
                          final date = v.recordedAt.length >= 10
                              ? v.recordedAt.substring(0, 10)
                              : v.recordedAt;
                          final rowBg = i.isEven
                              ? PdfColors.white
                              : const PdfColor.fromInt(0xFFF9F9F9);
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: rowBg),
                            children: [
                              _tableCell(date, ts, rtl),
                              _tableCell(v.type, ts, rtl),
                              _tableCell('${v.value} $unit', ts, rtl,
                                  valueColor: color, bold: true),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 7),
                                child: pw.Align(
                                  alignment: pw.Alignment.centerRight,
                                  child: statusBadge(status, color),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),

                  // Vitals sparkline chart
                  _buildVitalsChart(allVitals),
                ],
                pw.SizedBox(height: 18),

                // ══ Medications Section ═══════════════════════════════════
                sectionHeader('الأدوية النشطة'),
                if (medications.isEmpty)
                  card(
                    child: rtl('لا توجد أدوية مسجَّلة.',
                        ts(11, color: textGrey)),
                  )
                else
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor, width: 0.7),
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Table(
                      border: pw.TableBorder(
                        horizontalInside:
                            pw.BorderSide(color: borderColor, width: 0.5),
                        verticalInside:
                            pw.BorderSide(color: borderColor, width: 0.5),
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.5), // Name
                        1: const pw.FlexColumnWidth(2.0), // Dose
                        2: const pw.FlexColumnWidth(2.5), // Frequency
                        3: const pw.FlexColumnWidth(2.0), // Time
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: tealLight),
                          children: [
                            _tableCell('اسم الدواء', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('الجرعة', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('التكرار', ts, rtl,
                                isHeader: true, teal: teal),
                            _tableCell('وقت الأخذ', ts, rtl,
                                isHeader: true, teal: teal),
                          ],
                        ),
                        // Data rows
                        ...medications.asMap().entries.map((entry) {
                          final i = entry.key;
                          final m = entry.value;
                          final rowBg = i.isEven
                              ? PdfColors.white
                              : const PdfColor.fromInt(0xFFF9F9F9);
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: rowBg),
                            children: [
                              _tableCell(m.name, ts, rtl, bold: true),
                              _tableCell(m.dose, ts, rtl),
                              _tableCell(m.frequency, ts, rtl),
                              _tableCell(m.timeOfDay, ts, rtl),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Page Header ───────────────────────────────────────────────────────────
  pw.Widget _buildPageHeader({
    required FamilyMember member,
    required String memberNum,
    required pw.Font amiri,
    required Function ts,
    required Function rtl,
    required PdfColor teal,
    required PdfColor tealDark,
    required PdfColor tealMid,
    required PdfColor white,
    required PdfColor textLight,
    required pw.Context ctx,
  }) {
    return pw.Container(
      color: teal,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Main header bar
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(24, 18, 24, 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Left: Date + page number
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: tealDark,
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: rtl(
                          'تاريخ التقرير: ${_today()}',
                          pw.TextStyle(
                              font: amiri,
                              fontSize: 8.5,
                              color: PdfColors.white)),
                    ),
                    pw.SizedBox(height: 4),
                    rtl(
                        'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
                        pw.TextStyle(
                            font: amiri, fontSize: 7.5, color: tealMid)),
                  ],
                ),

                // Right: App name + member name
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        rtl(
                            'عيلتي',
                            pw.TextStyle(
                                font: amiri,
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                        pw.SizedBox(width: 8),
                        // Logo circle
                        pw.Container(
                          width: 32,
                          height: 32,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              '3',
                              textDirection: pw.TextDirection.ltr,
                              style: pw.TextStyle(
                                  font: amiri,
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                  color: teal),
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    rtl(
                        'تقرير صحي شامل',
                        pw.TextStyle(
                            font: amiri,
                            fontSize: 9,
                            color: tealMid,
                            fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),

          // Sub-bar: patient quick info
          pw.Container(
            color: tealDark,
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: membership
                pw.Row(children: [
                  pw.Container(
                    width: 6,
                    height: 6,
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.white, shape: pw.BoxShape.circle),
                  ),
                  pw.SizedBox(width: 5),
                  rtl(
                      memberNum,
                      pw.TextStyle(
                          font: amiri,
                          fontSize: 9,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 4),
                  rtl(
                      'رقم العضوية:',
                      pw.TextStyle(
                          font: amiri, fontSize: 9, color: tealMid)),
                ]),
                // Right: name + profile type
                pw.Row(children: [
                  rtl(
                      '${member.profileType.label}  •  ${member.name}',
                      pw.TextStyle(
                          font: amiri,
                          fontSize: 9.5,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page Footer ───────────────────────────────────────────────────────────
  pw.Widget _buildPageFooter({
    required pw.Font amiri,
    required Function ts,
    required Function rtl,
    required PdfColor textGrey,
    required PdfColor teal,
    required PdfColor borderColor,
    required pw.Context ctx,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(24, 10, 24, 12),
      decoration: pw.BoxDecoration(
        border: const pw.Border(
            top: pw.BorderSide(
                color: PdfColor.fromInt(0xFFE0F2F1), width: 2)),
        color: PdfColors.white,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left: date
          pw.Text(
            _today(),
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
                font: amiri, fontSize: 7.5, color: textGrey),
          ),
          // Center: privacy notice
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12),
              child: rtl(
                'صُنِع بواسطة تطبيق عيلتي لإدارة صحة الأسرة — جميع البيانات مُشفَّرة لحماية خصوصيتك وخصوصية عائلتك',
                pw.TextStyle(
                    font: amiri,
                    fontSize: 7,
                    color: textGrey,
                    fontStyle: pw.FontStyle.italic),
                align: pw.TextAlign.center,
              ),
            ),
          ),
          // Right: logo text
          pw.Row(children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                color: teal,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text('3',
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(
                        font: amiri,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
            ),
            pw.SizedBox(width: 3),
            pw.Text('3elty',
                textDirection: pw.TextDirection.ltr,
                style: pw.TextStyle(
                    font: amiri,
                    fontSize: 8,
                    color: teal,
                    fontWeight: pw.FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  // ── Table cell helper ─────────────────────────────────────────────────────
  static pw.Widget _tableCell(
    String text,
    Function ts,
    Function rtl, {
    bool isHeader = false,
    bool bold = false,
    PdfColor? teal,
    PdfColor? valueColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: rtl(
          text,
          ts(
            isHeader ? 10.0 : 9.5,
            bold: isHeader || bold,
            color: valueColor ?? (isHeader ? teal : null),
          ),
        ),
      ),
    );
  }

  // ── Info row (label : value) ──────────────────────────────────────────────
  static pw.Widget _infoRow(
    String label,
    String value,
    Function ts,
    Function rtl, {
    PdfColor? textGrey,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        rtl(value,
            ts(11.0,
                bold: true,
                color: valueColor ?? const PdfColor.fromInt(0xFF212121))),
        rtl(label, ts(10.0, color: textGrey ?? const PdfColor.fromInt(0xFF757575))),
      ],
    );
  }

  // ── Generate membership number from memberId ──────────────────────────────
  String _membershipNumber(String memberId) {
    int hash = 0;
    for (final c in memberId.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFF;
    }
    return '#ELT-${hash.toString().padLeft(4, '0')}';
  }

  // ── Today's date ──────────────────────────────────────────────────────────
  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}