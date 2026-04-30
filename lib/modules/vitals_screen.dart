import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';
import '../services/notification_helper.dart';
import '../services/report_service.dart';

class VitalsScreen extends StatefulWidget {
  final FamilyMember member;
  const VitalsScreen({super.key, required this.member});
  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen>
    with SingleTickerProviderStateMixin {
  final _repo        = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<VitalRecord> _vitals = [];
  bool _loading    = true;
  bool _generating = false;
  String _chartType = 'ضغط الدم (الانقباضي)';
  late TabController _tabController;

  static const List<String> _vitalTypes = [
    'ضغط الدم (الانقباضي)',
    'ضغط الدم (الانبساطي)',
    'سكر الدم',
    'معدل ضربات القلب',
    'درجة الحرارة',
  ];

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
    'درجة الحرارة':          '\u00b0C',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _vitalTypes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _chartType = _vitalTypes[_tabController.index]);
      }
    });
    _loadVitals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) { setState(() => _loading = false); return; }
    try {
      setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() { _vitals = vitals; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل العلامات الحيوية: $e');
    }
  }

  List<VitalRecord> get _chartVitals {
    final filtered = _vitals.where((v) => v.type == _chartType).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return filtered.length > 20 ? filtered.sublist(filtered.length - 20) : filtered;
  }

  List<FlSpot> get _chartSpots => List.generate(
      _chartVitals.length, (i) => FlSpot(i.toDouble(), _chartVitals[i].value));

  Color _statusColor(String type, double value) {
    final r = _normalRanges[type];
    if (r == null) return AppColors.teal;
    if (value < r['min']!) return const Color(0xFF1565C0);
    if (value > r['max']!) return AppColors.red;
    return AppColors.green;
  }

  String _statusLabel(String type, double value) {
    final r = _normalRanges[type];
    if (r == null) return '\u2014';
    if (value < r['min']!) return 'أقل من الطبيعي';
    if (value > r['max']!) return 'أعلى من الطبيعي';
    return 'ضمن الطبيعي';
  }

  Future<void> _generateReport() async {
    if (widget.member.id == null) return;
    setState(() => _generating = true);
    try {
      await ReportService.instance.generateAndShare(
        member: widget.member, memberId: widget.member.id!);
    } catch (e) {
      if (!mounted) return;
      _showError('تعذّر إنشاء التقرير: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _showAddVitalDialog() async {
    final valueCtrl = TextEditingController();
    String selectedType = _chartType;
    String selectedUnit = _units[selectedType] ?? 'mmHg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('تسجيل علامة حيوية',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('النوع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey600)),
              DropdownButton<String>(
                value: selectedType, isExpanded: true,
                items: _vitalTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setS(() { selectedType = v ?? selectedType; selectedUnit = _units[selectedType] ?? 'mmHg'; }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: valueCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'القيمة',
                  hintText: 'مثال: ${_normalRanges[selectedType]?['min']?.toStringAsFixed(0) ?? "120"}',
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                ),
              ),
              if (_normalRanges[selectedType] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'الطبيعي: ${_normalRanges[selectedType]!['min']} – ${_normalRanges[selectedType]!['max']} $selectedUnit',
                  style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final double? val = double.tryParse(valueCtrl.text);
                    if (val == null || widget.member.id == null) { _showError('يرجى إدخال رقم صحيح'); return; }
                    if (selectedType == 'درجة الحرارة' && (val > 45 || val < 32)) { _showError('درجة حرارة غير منطقية!'); return; }
                    if (selectedType == 'سكر الدم' && (val > 600 || val < 20)) { _showError('قيمة سكر غير معقولة!'); return; }
                    if (selectedType.contains('ضغط الدم') && (val > 260 || val < 40)) { _showError('قيمة ضغط مستحيلة!'); return; }
                    String? warning;
                    final r = _normalRanges[selectedType];
                    if (r != null) {
                      if (val > r['max']!) warning = 'انتباه: القيمة أعلى من المعدل الطبيعي.';
                      else if (val < r['min']!) warning = 'انتباه: القيمة أقل من المعدل الطبيعي.';
                    }
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final familyId = await _authService.familyId;
                      if (!mounted) return;
                      if (familyId == null) { _showError('لم يتم العثور على العائلة.'); return; }
                      await _repo.insertVital(VitalRecord(
                        familyId: familyId, memberId: widget.member.id!,
                        type: selectedType, value: val, unit: selectedUnit));
                      await NotificationHelper.instance.scheduleDailyVitalsReminder(
                        memberId: widget.member.id!, memberName: widget.member.name, hour: 9, minute: 0);
                      if (!mounted) return;
                      navigator.pop();
                      _loadVitals();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: warning != null ? AppColors.orange : AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Text(warning ?? 'تم تسجيل العلامة الحيوية بنجاح \u2713',
                            style: const TextStyle(color: Colors.white))));
                    } catch (e) { _showError('فشل الحفظ: $e'); }
                  },
                  child: const Text('تسجيل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white))));

  IconData _iconForType(String type) {
    if (type.contains('ضغط')) return Icons.water_drop_rounded;
    if (type.contains('سكر')) return Icons.bloodtype_rounded;
    if (type.contains('قلب')) return Icons.favorite_rounded;
    if (type.contains('حرارة')) return Icons.thermostat_rounded;
    return Icons.monitor_heart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('العلامات الحيوية'),
        actions: [
          _generating
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'إنشاء تقرير PDF',
                  onPressed: _generateReport),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white, padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(width: 48, height: 48,
                          decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                          child: Icon(t.icon, color: t.color, size: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                        Text(t.label, style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w500)),
                      ])),
                      if (_vitals.isNotEmpty)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          const Text('آخر قراءة', style: TextStyle(fontSize: 11, color: AppColors.grey500)),
                          Text('${_vitals.first.value} ${_vitals.first.unit}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                  color: _statusColor(_vitals.first.type, _vitals.first.value))),
                          Text(_vitals.first.type, style: const TextStyle(fontSize: 10, color: AppColors.grey600)),
                        ]),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),

                SliverToBoxAdapter(
                  child: _vitals.isEmpty
                      ? Padding(padding: const EdgeInsets.all(48),
                          child: Center(child: Column(children: [
                            Container(padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
                                child: const Icon(Icons.favorite_rounded, size: 48, color: AppColors.teal)),
                            const SizedBox(height: 20),
                            const Text('لا توجد علامات حيوية بعد',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                            const SizedBox(height: 8),
                            const Text('سجّل أول قراءة للبدء',
                                style: TextStyle(fontSize: 14, color: AppColors.grey600)),
                          ])))
                      : _ChartSection(
                          vitalTypes: _vitalTypes, tabController: _tabController,
                          chartVitals: _chartVitals, chartSpots: _chartSpots,
                          chartType: _chartType, normalRanges: _normalRanges,
                          units: _units, statusColor: _statusColor, statusLabel: _statusLabel),
                ),

                if (_vitals.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: const Text('آخر القراءات',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900))),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: _vitals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final v = _vitals[i];
                        final color = _statusColor(v.type, v.value);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withValues(alpha: 0.2))),
                          child: Row(children: [
                            Container(width: 42, height: 42,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_iconForType(v.type), color: color, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(v.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                              const SizedBox(height: 2),
                              Text(v.recordedAt.length >= 10 ? v.recordedAt.substring(0, 10) : v.recordedAt,
                                  style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${v.value} ${v.unit}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text(_statusLabel(v.type, v.value),
                                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVitalDialog,
        backgroundColor: AppColors.teal, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded), label: const Text('تسجيل علامة')),
    );
  }
}

// ── Chart Section ─────────────────────────────────────────────────────────────
class _ChartSection extends StatelessWidget {
  final List<String> vitalTypes;
  final TabController tabController;
  final List<VitalRecord> chartVitals;
  final List<FlSpot> chartSpots;
  final String chartType;
  final Map<String, Map<String, double>> normalRanges;
  final Map<String, String> units;
  final Color Function(String, double) statusColor;
  final String Function(String, double) statusLabel;

  const _ChartSection({
    required this.vitalTypes, required this.tabController, required this.chartVitals,
    required this.chartSpots, required this.chartType, required this.normalRanges,
    required this.units, required this.statusColor, required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = chartSpots.length >= 2;
    final latest  = chartVitals.isNotEmpty ? chartVitals.last : null;
    final unit    = units[chartType] ?? '';
    final range   = normalRanges[chartType];

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: tabController, isScrollable: true,
            labelColor: AppColors.teal, unselectedLabelColor: AppColors.grey500,
            indicatorColor: AppColors.teal,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabAlignment: TabAlignment.start,
            tabs: vitalTypes.map((t) => Tab(text: t)).toList(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(chartType, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey900)),
              if (range != null)
                Text('الطبيعي: ${range['min']} \u2013 ${range['max']} $unit',
                    style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ]),
          ),
          if (latest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Text('${latest.value} $unit',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: statusColor(chartType, latest.value))),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor(chartType, latest.value).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel(chartType, latest.value),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: statusColor(chartType, latest.value))),
                ),
              ]),
            ),
          if (!hasData)
            const Padding(padding: EdgeInsets.all(24),
                child: Center(child: Text('أدخل قراءتين على الأقل لعرض الرسم البياني',
                    style: TextStyle(color: AppColors.grey500, fontSize: 13), textAlign: TextAlign.center)))
          else
            _VitalsLineChart(
              spots: chartSpots, vitals: chartVitals,
              normalMin: range?['min'], normalMax: range?['max'],
              lineColor: statusColor(chartType, chartVitals.isNotEmpty ? chartVitals.last.value : 0),
              unit: unit,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── fl_chart Line Chart ───────────────────────────────────────────────────────
class _VitalsLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final List<VitalRecord> vitals;
  final double? normalMin;
  final double? normalMax;
  final Color lineColor;
  final String unit;

  const _VitalsLineChart({
    required this.spots, required this.vitals, required this.normalMin,
    required this.normalMax, required this.lineColor, required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) return const SizedBox.shrink();
    final allY = [...spots.map((s) => s.y)];
    if (normalMin != null) allY.add(normalMin!);
    if (normalMax != null) allY.add(normalMax!);
    final yMin = (allY.reduce((a, b) => a < b ? a : b) - 10).clamp(0, double.infinity).toDouble();
    final yMax = allY.reduce((a, b) => a > b ? a : b) + 10;

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
        child: LineChart(
          LineChartData(
            minY: yMin, maxY: yMax, minX: 0, maxX: (spots.length - 1).toDouble(),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              horizontalInterval: (yMax - yMin) / 4,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.grey200, strokeWidth: 1)),
            borderData: FlBorderData(show: true,
                border: const Border(bottom: BorderSide(color: AppColors.grey200),
                    left: BorderSide(color: AppColors.grey200))),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                interval: (yMax - yMin) / 4,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AppColors.grey500)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 24,
                interval: spots.length > 10 ? (spots.length / 5).ceilToDouble() : 1,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= vitals.length) return const SizedBox.shrink();
                  final d = vitals[idx].recordedAt;
                  return Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(d.length >= 10 ? d.substring(5, 10) : '',
                          style: const TextStyle(fontSize: 9, color: AppColors.grey500)));
                })),
            ),
            rangeAnnotations: (normalMin != null && normalMax != null)
                ? RangeAnnotations(horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: normalMin!, y2: normalMax!,
                        color: AppColors.green.withValues(alpha: 0.08))])
                : const RangeAnnotations(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.grey900,
                tooltipRoundedRadius: 8,
                getTooltipItems: (pts) => pts.map((s) {
                  final d = s.spotIndex < vitals.length
                      ? vitals[s.spotIndex].recordedAt.substring(0, 10) : '';
                  return LineTooltipItem('${s.y.toStringAsFixed(1)} $unit\n$d',
                      const TextStyle(color: Colors.white, fontSize: 11));
                }).toList())),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.35,
                color: lineColor, barWidth: 2.5, isStrokeCapRound: true,
                dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) {
                  final isLast = spot.x == spots.last.x;
                  return FlDotCirclePainter(radius: isLast ? 5 : 3, color: lineColor,
                      strokeWidth: 2, strokeColor: Colors.white);
                }),
                belowBarData: BarAreaData(show: true,
                    gradient: LinearGradient(
                        colors: [lineColor.withValues(alpha: 0.2), lineColor.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
              if (normalMin != null) LineChartBarData(
                spots: [FlSpot(0, normalMin!), FlSpot((spots.length - 1).toDouble(), normalMin!)],
                color: AppColors.green.withValues(alpha: 0.5), barWidth: 1,
                dotData: const FlDotData(show: false), dashArray: [6, 4]),
              if (normalMax != null) LineChartBarData(
                spots: [FlSpot(0, normalMax!), FlSpot((spots.length - 1).toDouble(), normalMax!)],
                color: AppColors.green.withValues(alpha: 0.5), barWidth: 1,
                dotData: const FlDotData(show: false), dashArray: [6, 4]),
            ],
          ),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }
}