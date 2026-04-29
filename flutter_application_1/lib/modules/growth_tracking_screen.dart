import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

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

  // ── WHO Growth Reference (Boys, height cm, weight kg) by age in years ──────
  // Each entry: {ageLabel, minHeight, maxHeight, minWeight, maxWeight}
  // Source: WHO Child Growth Standards (simplified P3–P97 ranges)
  static const _whoRanges = [
    {'ageLabel': 'ولادة',  'ageYears': 0,  'minH': 46.1, 'maxH': 53.4, 'minW': 2.5,  'maxW': 4.3},
    {'ageLabel': '٣ أشهر', 'ageYears': 0,  'minH': 57.3, 'maxH': 65.5, 'minW': 4.4,  'maxW': 7.7},
    {'ageLabel': '٦ أشهر', 'ageYears': 0,  'minH': 63.3, 'maxH': 71.9, 'minW': 5.7,  'maxW': 9.7},
    {'ageLabel': '١٢ شهر', 'ageYears': 1,  'minH': 71.0, 'maxH': 80.5, 'minW': 7.1,  'maxW': 12.0},
    {'ageLabel': '٢ سنة',  'ageYears': 2,  'minH': 81.7, 'maxH': 93.9, 'minW': 9.0,  'maxW': 15.3},
    {'ageLabel': '٣ سنوات','ageYears': 3,  'minH': 88.7, 'maxH': 102.7,'minW': 10.8, 'maxW': 18.1},
    {'ageLabel': '٤ سنوات','ageYears': 4,  'minH': 94.9, 'maxH': 111.0,'minW': 12.3, 'maxW': 21.2},
    {'ageLabel': '٥ سنوات','ageYears': 5,  'minH': 100.7,'maxH': 118.9,'minW': 13.7, 'maxW': 24.5},
    {'ageLabel': '٦ سنوات','ageYears': 6,  'minH': 106.1,'maxH': 126.6,'minW': 15.3, 'maxW': 28.2},
    {'ageLabel': '٧ سنوات','ageYears': 7,  'minH': 111.2,'maxH': 133.9,'minW': 16.8, 'maxW': 32.3},
    {'ageLabel': '٨ سنوات','ageYears': 8,  'minH': 115.9,'maxH': 141.0,'minW': 18.5, 'maxW': 37.3},
    {'ageLabel': '٩ سنوات','ageYears': 9,  'minH': 120.6,'maxH': 148.0,'minW': 20.3, 'maxW': 43.1},
    {'ageLabel': '١٠ سنوات','ageYears':10, 'minH': 125.2,'maxH': 155.0,'minW': 22.4, 'maxW': 49.9},
  ];

  // Find the closest WHO range entry for this child
  Map<String, dynamic>? get _whoForAge {
    final age = widget.member.age;
    // Exact match first, then closest
    Map<String, dynamic>? best;
    int bestDiff = 9999;
    for (final r in _whoRanges) {
      final diff = ((r['ageYears'] as num) - age).abs().toInt();
      if (diff < bestDiff) { bestDiff = diff; best = r; }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) { setState(() => _loading = false); return; }
    try {
      setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      final filtered = vitals.where((v) => v.type == 'height' || v.type == 'weight').toList();
      setState(() { _vitals = filtered; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل بيانات النمو: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showAddDialog() {
    final heightCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل بيانات النمو'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: heightCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'الطول (سم)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.straighten, color: AppColors.teal))),
          const SizedBox(height: 12),
          TextField(controller: weightCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'الوزن (كجم)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.scale, color: AppColors.green))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final hStr = heightCtrl.text.trim();
              final wStr = weightCtrl.text.trim();
              if (hStr.isEmpty && wStr.isEmpty) { _showError('أدخل الطول أو الوزن'); return; }
              final nav = Navigator.of(ctx);
              try {
                final familyId = await _authService.familyId;
                if (!mounted) return;
                if (familyId == null) { _showError('لم يتم العثور على العائلة'); return; }
                if (hStr.isNotEmpty) {
                  final h = double.tryParse(hStr);
                  if (h == null || h <= 0) { _showError('الطول يجب أن يكون رقماً موجباً'); return; }
                  await _repo.insertVital(VitalRecord(familyId: familyId, memberId: widget.member.id!, type: 'height', value: h, unit: 'cm'));
                }
                if (wStr.isNotEmpty) {
                  final w = double.tryParse(wStr);
                  if (w == null || w <= 0) { _showError('الوزن يجب أن يكون رقماً موجباً'); return; }
                  await _repo.insertVital(VitalRecord(familyId: familyId, memberId: widget.member.id!, type: 'weight', value: w, unit: 'kg'));
                }
                if (!mounted) return;
                nav.pop();
                _showSuccess('تم تسجيل بيانات النمو');
                await _loadVitals();
              } catch (e) { _showError('تعذّر الحفظ: $e'); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Status compared to WHO range
  _RangeStatus _heightStatus(double h) {
    final who = _whoForAge;
    if (who == null) return _RangeStatus.normal;
    if (h < (who['minH'] as double)) return _RangeStatus.low;
    if (h > (who['maxH'] as double)) return _RangeStatus.high;
    return _RangeStatus.normal;
  }

  _RangeStatus _weightStatus(double w) {
    final who = _whoForAge;
    if (who == null) return _RangeStatus.normal;
    if (w < (who['minW'] as double)) return _RangeStatus.low;
    if (w > (who['maxW'] as double)) return _RangeStatus.high;
    return _RangeStatus.normal;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    final heights = _vitals.where((v) => v.type == 'height').toList();
    final weights = _vitals.where((v) => v.type == 'weight').toList();
    final latestH = heights.isNotEmpty ? heights.last : null;
    final latestW = weights.isNotEmpty ? weights.last : null;
    final who = _whoForAge;

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('تتبع النمو')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(t.icon, color: t.color, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                      Text('${widget.member.age} سنة', style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // ── WHO Reference Card ──
              if (who != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.06),
                          border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.teal),
                          const SizedBox(width: 6),
                          Text('نطاق WHO لعمر ${who['ageLabel']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.teal)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _RangeInfo(label: 'الطول', value: '${who['minH']} – ${who['maxH']} سم', icon: Icons.straighten)),
                          const SizedBox(width: 12),
                          Expanded(child: _RangeInfo(label: 'الوزن', value: '${who['minW']} – ${who['maxW']} كجم', icon: Icons.scale)),
                        ]),
                      ]),
                    ),
                  ),
                ),

              // ── Current measurements ──
              if (latestH != null || latestW != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('القياسات الحالية',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (latestH != null) Expanded(child: _MeasurementCard(
                          label: 'الطول', value: '${latestH.value}', unit: latestH.unit,
                          icon: Icons.straighten, color: AppColors.teal,
                          status: _heightStatus(latestH.value as double),
                        )),
                        if (latestH != null && latestW != null) const SizedBox(width: 12),
                        if (latestW != null) Expanded(child: _MeasurementCard(
                          label: 'الوزن', value: '${latestW.value}', unit: latestW.unit,
                          icon: Icons.scale, color: AppColors.green,
                          status: _weightStatus(latestW.value as double),
                        )),
                      ]),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),

              // ── History ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: const Text('سجل القياسات',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                ),
              ),

              if (_vitals.isEmpty)
                SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.trending_up_outlined, size: 64, color: AppColors.grey200),
                  const SizedBox(height: 16),
                  const Text('لا توجد قياسات بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600)),
                ])))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: _vitals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final v = _vitals[i];
                      final isH = v.type == 'height';
                      return Material(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Container(width: 40, height: 40,
                                decoration: BoxDecoration(
                                    color: (isH ? AppColors.teal : AppColors.green).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(isH ? Icons.straighten : Icons.scale,
                                    color: isH ? AppColors.teal : AppColors.green, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(isH ? 'الطول' : 'الوزن',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                              Text('${v.value} ${v.unit}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                            ])),
                            Text(v.recordedAt?.toString().split(' ').first ?? '',
                                style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

enum _RangeStatus { low, normal, high }

// ── Small widgets ─────────────────────────────────────────────────────────────

class _RangeInfo extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _RangeInfo({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.teal),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey900)),
      ])),
    ]),
  );
}

class _MeasurementCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final _RangeStatus status;
  const _MeasurementCard({required this.label, required this.value, required this.unit, required this.icon, required this.color, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = status == _RangeStatus.normal ? AppColors.green : AppColors.red;
    final statusLabel = status == _RangeStatus.low ? '⬇ أقل من المعدل'
        : status == _RangeStatus.high ? '⬆ أعلى من المعدل' : '✓ ضمن المعدل';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.grey600, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 8),
          Text('$value $unit', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
      ),
    );
  }
}
