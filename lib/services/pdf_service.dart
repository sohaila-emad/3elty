import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../data/app_repository.dart';
import 'package:intl/intl.dart';

/// Service for generating PDF documents
class PDFService {
  PDFService._();
  static final PDFService instance = PDFService._();

  factory PDFService() => instance;

  final _repo = AppRepository.instance;

  /// Generate one-page medical profile PDF
  Future<File> generateMedicalProfilePDF({
    required FamilyMember member,
    required String bloodType,
    required List<String> conditions,
    required List<String> allergies,
    String? pastSurgeries,
    List<String>? currentMedications,
  }) async {
    final pdf = pw.Document();

    // Load Amiri font for Arabic text support
    pw.Font amiri;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      amiri = pw.Font.ttf(fontData);
    } catch (_) {
      amiri = pw.Font.helvetica();
    }

    // Helper: wraps any text widget with RTL direction and Amiri font
    pw.TextStyle arabicStyle(pw.TextStyle base) => base.copyWith(font: amiri);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'MEDICAL PROFILE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('00796B'),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Emergency Reference Card',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColor.fromHex('757575'),
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 12),

              // Member info
              _buildSection(
                title: 'PERSONAL INFORMATION',
                children: [
                  _buildInfoRow('Name:', member.name),
                  _buildInfoRow('Age:', '${member.age} years'),
                  _buildInfoRow('Profile Type:', member.profileType.label),
                  _buildInfoRow('Generated:', DateFormat('MMM dd, yyyy').format(DateTime.now())),
                ],
              ),
              pw.SizedBox(height: 16),

              // Blood type - prominently displayed
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('D32F2F')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  color: PdfColor.fromHex('FFEBEE'),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'BLOOD TYPE:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('D32F2F'),
                      ),
                    ),
                    pw.Spacer(),
                    pw.Text(
                      bloodType.isEmpty ? 'Not recorded' : bloodType,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('D32F2F'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Chronic conditions
              if (conditions.isNotEmpty)
                _buildSection(
                  title: 'CHRONIC CONDITIONS',
                  children: conditions
                      .map((c) => pw.Row(children: [
                            pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(child: pw.Text(c, style: const pw.TextStyle(fontSize: 11))),
                          ]))
                      .toList(),
                )
              else
                _buildSection(
                  title: 'CHRONIC CONDITIONS',
                  children: [pw.Text('No known conditions', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey))],  
                ),

              if (conditions.isNotEmpty) pw.SizedBox(height: 12),

              // Allergies
              if (allergies.isNotEmpty)
                _buildSection(
                  title: 'ALLERGIES',
                  children: allergies
                      .map((a) => pw.Row(children: [
                            pw.Text('⚠ ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(child: pw.Text(a, style: const pw.TextStyle(fontSize: 11))),
                          ]))
                      .toList(),
                )
              else
                _buildSection(
                  title: 'ALLERGIES',
                  children: [pw.Text('No known allergies', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey))],
                ),

              if (allergies.isNotEmpty) pw.SizedBox(height: 12),

              // Past surgeries
              if (pastSurgeries != null && pastSurgeries.isNotEmpty)
                _buildSection(
                  title: 'PAST SURGERIES',
                  children: [pw.Text(pastSurgeries, style: const pw.TextStyle(fontSize: 11))],
                ),

              if (pastSurgeries != null && pastSurgeries.isNotEmpty) pw.SizedBox(height: 12),

              // Current medications
              if (currentMedications != null && currentMedications.isNotEmpty)
                _buildSection(
                  title: 'CURRENT MEDICATIONS',
                  children: currentMedications
                      .map((m) => pw.Row(children: [
                            pw.Text('💊 ', style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(child: pw.Text(m, style: const pw.TextStyle(fontSize: 11))),
                          ]))
                      .toList(),
                ),

              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Text(
                '⚠️ Please review and update this information with your doctor.',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('D32F2F'),
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ));
        },
      ),
    );

    return _savePDF(pdf, 'medical_profile_${member.name}_${DateTime.now().millisecondsSinceEpoch}');
  }

  /// Generate monthly clinical summary for chronic patients
  Future<File> generateMonthlyClinicalSummary({
    required FamilyMember member,
    required DateTime month,
    required List<Map<String, dynamic>> vitals,
    required Map<String, dynamic> medicationAdherence,
  }) async {
    final pdf = pw.Document();

    // Load Amiri font for Arabic text support
    pw.Font amiri;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      amiri = pw.Font.ttf(fontData);
    } catch (_) {
      amiri = pw.Font.helvetica();
    }

    // Calculate statistics
    final avgSystolic = vitals
        .where((v) => v['type'] == 'Blood Pressure (Systolic)')
        .map((v) => v['value'] as double)
        .fold<double>(0, (a, b) => a + b) /
        (vitals.where((v) => v['type'] == 'Blood Pressure (Systolic)').length ?? 1);

    final adherenceRate = medicationAdherence['adherence_percentage'] as double? ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'MONTHLY CLINICAL SUMMARY',
                  style: pw.TextStyle(
                    font: amiri,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('00796B'),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: pw.TextStyle(font: amiri, fontSize: 12, color: PdfColors.grey),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 12),

              // Member info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Patient: ${member.name}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Age: ${member.age}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Vital statistics
              _buildSection(
                title: 'VITAL STATISTICS',
                children: [
                  _buildStatRow('Average Systolic BP:', '${avgSystolic.toStringAsFixed(1)} mmHg'),
                  _buildStatRow('Total Readings:', '${vitals.length} recorded'),
                  _buildStatRow('Medication Adherence:', '${adherenceRate.toStringAsFixed(1)}%'),
                ],
              ),
              pw.SizedBox(height: 16),

              // Summary
              _buildSection(
                title: 'SUMMARY FOR DOCTOR',
                children: [
                  pw.Text(
                    'This patient has maintained consistent monitoring throughout the month with ${vitals.length} vital sign measurements recorded. '
                    'Medication adherence is at ${adherenceRate.toStringAsFixed(0)}%, indicating ',
                    style: const pw.TextStyle(fontSize: 10, height: 1.5),
                  ),
                  pw.Text(
                    adherenceRate >= 80
                        ? 'good compliance with treatment plan.'
                        : adherenceRate >= 60
                            ? 'room for improvement in compliance.'
                            : 'significant adherence challenges that require attention.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: pw.FontWeight.bold,
                      color: adherenceRate >= 80
                          ? PdfColor.fromHex('2E7D32')
                          : adherenceRate >= 60
                              ? PdfColor.fromHex('F57C00')
                              : PdfColor.fromHex('D32F2F'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Recommendations
              _buildSection(
                title: 'RECOMMENDATIONS FOR NEXT VISIT',
                children: [
                  pw.Text(
                    '• Review current medication efficacy\n'
                    '• Discuss any missed doses or challenges\n'
                    '• Update vital sign baseline if needed\n'
                    '• Schedule follow-up blood work if required',
                    style: const pw.TextStyle(fontSize: 10, height: 1.6),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Text(
                'This summary was automatically generated by the 3elty Health Companion app and should be reviewed with your healthcare provider.',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColor.fromHex('999999'),
                  fontStyle: pw.FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ],
          ));
        },
      ),
    );

    return _savePDF(pdf, 'clinical_summary_${member.name}_${month.year}_${month.month}');
  }

  /// Helper to build section
  static pw.Widget _buildSection({
    required String title,
    required List<pw.Widget> children,
    pw.Font? font,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('00796B'),
          ),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    );
  }

  /// Helper to build info row
  static pw.Widget _buildInfoRow(String label, String value, {pw.Font? font}) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(label,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Expanded(
          child: pw.Text(value,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10)),
        ),
      ],
    );
  }

  /// Helper to build stat row
  static pw.Widget _buildStatRow(String label, String value, {pw.Font? font}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text(value,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Save PDF to device
  Future<File> _savePDF(pw.Document pdf, String filename) async {
    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/$filename.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
