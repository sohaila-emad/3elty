import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart';
import '../data/app_repository.dart';

class MedicalPdfExportScreen extends StatefulWidget {
  final FamilyMember member;
  const MedicalPdfExportScreen({super.key, required this.member});

  @override
  State<MedicalPdfExportScreen> createState() => _MedicalPdfExportScreenState();
}

class _MedicalPdfExportScreenState extends State<MedicalPdfExportScreen> {
  final _repo = AppRepository.instance;

  bool _includeFullMedications = true;
  bool _hideSensitiveData = false;
  bool _generating = false;

  List<VitalRecord> _vitals = [];
  List<MedicationRecord> _medications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      final meds = await _repo.getMedicationsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _vitals = vitals;
        _medications = meds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Generate membership number from member id ──────────────────────────────
  String get _membershipNumber {
    final id = widget.member.id ?? 'unknown';
    final short = id.length > 5 ? id.substring(0, 5).toUpperCase() : id.toUpperCase();
    return '#ELT-$short';
  }

  // ── Generate PDF bytes ─────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf() async {
    final doc = pw.Document();
    final member = widget.member;
    final t = member.profileType;
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── Header ──────────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('3elty',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal)),
                    pw.Text('Family Health Management Platform',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600)),
                    pw.SizedBox(height: 4),
                    pw.Text('Report Date: $dateStr',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Container(
                  width: 60,
                  height: 60,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.teal,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Center(
                    child: pw.Text('3elty',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Patient Data ─────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Container(
                    width: 4,
                    height: 18,
                    color: PdfColors.teal,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text('Patient Data',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Full Name',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _hideSensitiveData ? '*** ***' : member.name,
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Age',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.SizedBox(height: 2),
                          pw.Text('${member.age} years',
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Profile Type',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.SizedBox(height: 2),
                          pw.Text(t.label,
                              style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Membership Number',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _hideSensitiveData ? '***' : _membershipNumber,
                            style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Latest Vitals ────────────────────────────────────────────────
          if (_vitals.isNotEmpty) ...[
            pw.Row(children: [
              pw.Container(width: 4, height: 18, color: PdfColors.teal),
              pw.SizedBox(width: 8),
              pw.Text('Latest Vitals',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Date',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Type',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Value',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ],
                ),
                ..._vitals.take(5).map((v) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            v.recordedAt.isNotEmpty ? v.recordedAt.substring(0, 10) : '-',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            v.type,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${v.value} ${v.unit}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Medications ──────────────────────────────────────────────────
          if (_includeFullMedications && _medications.isNotEmpty) ...[
            pw.Row(children: [
              pw.Container(width: 4, height: 18, color: PdfColors.teal),
              pw.SizedBox(width: 8),
              pw.Text('Medication Record',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Medication',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Dose',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Frequency',
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ],
                ),
                ..._medications.map((m) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(m.name ?? '-',
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(m.dose ?? '-',
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(m.frequency ?? '-',
                              style: const pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Footer ───────────────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by 3elty — Family Health Management',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
              pw.Text('All data is encrypted for your family\'s privacy',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _downloadPdf() async {
    setState(() => _generating = true);
    try {
      final bytes = await _generatePdf();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '3elty_${widget.member.name}_medical_summary.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Failed to generate PDF: $e',
              style: const TextStyle(color: Colors.white)),
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _printPdf() async {
    setState(() => _generating = true);
    try {
      final bytes = await _generatePdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Failed to print: $e',
              style: const TextStyle(color: Colors.white)),
        ));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final t = member.profileType;
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.grey900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.grey200),
        ),
        title: const Text('Export Medical Summary',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Preview card ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Column(
                      children: [
                        // Card header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(color: AppColors.grey200)),
                          ),
                          child: Row(children: [
                            const Text('3elty',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.teal)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: t.bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(t.icon, color: t.color, size: 20),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Report date
                              Text('Report Date: $dateStr',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grey500)),
                              const SizedBox(height: 16),
                              const Divider(color: AppColors.grey200),
                              const SizedBox(height: 12),

                              // Section title
                              Row(children: [
                                Container(
                                    width: 3,
                                    height: 16,
                                    color: AppColors.teal),
                                const SizedBox(width: 8),
                                const Text('Patient Data',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.grey900)),
                              ]),
                              const SizedBox(height: 12),

                              // Patient info grid
                              Row(children: [
                                Expanded(
                                  child: _infoCell(
                                    'Full Name',
                                    _hideSensitiveData
                                        ? '*** ***'
                                        : member.name,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _infoCell('Age',
                                      '${member.age} years'),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: _infoCell(
                                      'Profile Type', t.label),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _infoCell(
                                    'Membership No.',
                                    _hideSensitiveData
                                        ? '***'
                                        : _membershipNumber,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),
                              const Divider(color: AppColors.grey200),
                              const SizedBox(height: 12),

                              // Latest vitals
                              Row(children: [
                                Container(
                                    width: 3,
                                    height: 16,
                                    color: AppColors.teal),
                                const SizedBox(width: 8),
                                const Text('Latest Vitals',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.grey900)),
                              ]),
                              const SizedBox(height: 8),
                              if (_vitals.isEmpty)
                                const Text('No vitals recorded yet',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.grey500))
                              else
                                ..._vitals.take(3).map((v) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: Row(children: [
                                        const Icon(
                                            Icons.fiber_manual_record,
                                            size: 6,
                                            color: AppColors.teal),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${v.type}: ${v.value} ${v.unit}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.grey700),
                                        ),
                                      ]),
                                    )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Action buttons ──────────────────────────────────────
                  _actionButton(
                    icon: Icons.download_rounded,
                    label: 'Download PDF',
                    backgroundColor: AppColors.teal,
                    textColor: Colors.white,
                    onTap: _generating ? null : _downloadPdf,
                    loading: _generating,
                  ),
                  const SizedBox(height: 10),
                  _actionButton(
                    icon: Icons.share_rounded,
                    label: 'Share via WhatsApp',
                    backgroundColor: Colors.white,
                    textColor: AppColors.grey900,
                    borderColor: AppColors.grey200,
                    onTap: _generating ? null : _downloadPdf,
                  ),
                  const SizedBox(height: 10),
                  _actionButton(
                    icon: Icons.print_rounded,
                    label: 'Print',
                    backgroundColor: Colors.white,
                    textColor: AppColors.grey900,
                    borderColor: AppColors.grey200,
                    onTap: _generating ? null : _printPdf,
                  ),
                  const SizedBox(height: 20),

                  // ── File settings ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('File Settings',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.grey900)),
                        const SizedBox(height: 14),
                        _settingToggle(
                          label: 'Include full medication record',
                          value: _includeFullMedications,
                          onChanged: (v) =>
                              setState(() => _includeFullMedications = v),
                        ),
                        const Divider(
                            height: 20, color: AppColors.grey200),
                        _settingToggle(
                          label: 'Hide sensitive personal data',
                          value: _hideSensitiveData,
                          onChanged: (v) =>
                              setState(() => _hideSensitiveData = v),
                        ),
                        const SizedBox(height: 14),
                        // Privacy note
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.teal, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'All data is encrypted when sharing to protect your family\'s privacy.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.teal,
                                    height: 1.4),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────────
  Widget _infoCell(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.grey500)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey900)),
        ],
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    VoidCallback? onTap,
    bool loading = false,
  }) =>
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: borderColor != null
                  ? BorderSide(color: borderColor)
                  : BorderSide.none,
            ),
          ),
          child: loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: textColor,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: textColor, size: 20),
                    const SizedBox(width: 10),
                    Text(label,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      );

  Widget _settingToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 14, color: AppColors.grey700)),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
          ),
        ),
      ]);
}
