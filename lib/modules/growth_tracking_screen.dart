import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

// ─── معايير منظمة الصحة العالمية (WHO) للوزن والطول ──────────────────────────
//
// يُستخدم عمر الطفل المُخزَّن في قاعدة البيانات:
//   - إذا كان مُخزَّناً بالشهور (ageInMonths = true): يُستخدم مباشرة
//   - إذا كان بالسنوات: يُحوَّل إلى شهور (× 12) للمقارنة
//
// المصدر: WHO Child Growth Standards 2006
// ─────────────────────────────────────────────────────────────────────────────

/// يُرجع النطاق الطبيعي لمنظمة الصحة العالمية للوزن (كجم) بناءً على العمر
/// [ageInMonths] = عمر الطفل بالشهور
/// يُرجع Map بمفاتيح: min, max, label
Map<String, dynamic> whoWeightRange(int ageInMonths) {
  if (ageInMonths <= 1)       return {'min': 2.9, 'max': 5.1,  'label': 'حديث الولادة'};
  if (ageInMonths <= 3)       return {'min': 4.4, 'max': 7.4,  'label': '1-3 أشهر'};
  if (ageInMonths <= 6)       return {'min': 5.7, 'max': 9.2,  'label': '3-6 أشهر'};
  if (ageInMonths <= 9)       return {'min': 6.9, 'max': 10.9, 'label': '6-9 أشهر'};
  if (ageInMonths <= 12)      return {'min': 7.7, 'max': 11.9, 'label': '9-12 شهراً'};
  if (ageInMonths <= 18)      return {'min': 8.8, 'max': 13.7, 'label': '1-1.5 سنة'};
  if (ageInMonths <= 24)      return {'min': 9.7, 'max': 15.3, 'label': '1.5-2 سنة'};
  if (ageInMonths <= 36)      return {'min': 11.0,'max': 18.3, 'label': '2-3 سنوات'};
  if (ageInMonths <= 48)      return {'min': 12.7,'max': 21.2, 'label': '3-4 سنوات'};
  if (ageInMonths <= 60)      return {'min': 14.1,'max': 24.2, 'label': '4-5 سنوات'};
  if (ageInMonths <= 72)      return {'min': 15.9,'max': 27.1, 'label': '5-6 سنوات'};
  if (ageInMonths <= 84)      return {'min': 17.7,'max': 30.7, 'label': '6-7 سنوات'};
  if (ageInMonths <= 96)      return {'min': 19.5,'max': 35.5, 'label': '7-8 سنوات'};
  if (ageInMonths <= 108)     return {'min': 21.8,'max': 40.9, 'label': '8-9 سنوات'};
  if (ageInMonths <= 120)     return {'min': 24.0,'max': 46.9, 'label': '9-10 سنوات'};
  if (ageInMonths <= 132)     return {'min': 26.8,'max': 53.7, 'label': '10-11 سنة'};
  if (ageInMonths <= 144)     return {'min': 30.0,'max': 61.2, 'label': '11-12 سنة'};
  if (ageInMonths <= 156)     return {'min': 33.8,'max': 67.8, 'label': '12-13 سنة'};
  if (ageInMonths <= 168)     return {'min': 38.0,'max': 73.5, 'label': '13-14 سنة'};
  if (ageInMonths <= 180)     return {'min': 42.5,'max': 78.2, 'label': '14-15 سنة'};
  if (ageInMonths <= 192)     return {'min': 46.8,'max': 81.0, 'label': '15-16 سنة'};
  if (ageInMonths <= 204)     return {'min': 50.2,'max': 82.8, 'label': '16-17 سنة'};
  return                             {'min': 52.9,'max': 84.0, 'label': '17-18 سنة'};
}

/// يُرجع النطاق الطبيعي لمنظمة الصحة العالمية للطول (سم) بناءً على العمر
Map<String, dynamic> whoHeightRange(int ageInMonths) {
  if (ageInMonths <= 1)       return {'min': 48.0,'max': 55.6, 'label': 'حديث الولادة'};
  if (ageInMonths <= 3)       return {'min': 55.6,'max': 63.2, 'label': '1-3 أشهر'};
  if (ageInMonths <= 6)       return {'min': 61.2,'max': 70.3, 'label': '3-6 أشهر'};
  if (ageInMonths <= 9)       return {'min': 66.3,'max': 75.9, 'label': '6-9 أشهر'};
  if (ageInMonths <= 12)      return {'min': 70.1,'max': 80.5, 'label': '9-12 شهراً'};
  if (ageInMonths <= 18)      return {'min': 74.2,'max': 85.7, 'label': '1-1.5 سنة'};
  if (ageInMonths <= 24)      return {'min': 81.7,'max': 93.9, 'label': '1.5-2 سنة'};
  if (ageInMonths <= 36)      return {'min': 88.7,'max': 102.7,'label': '2-3 سنوات'};
  if (ageInMonths <= 48)      return {'min': 95.0,'max': 111.3,'label': '3-4 سنوات'};
  if (ageInMonths <= 60)      return {'min': 100.7,'max':118.9,'label': '4-5 سنوات'};
  if (ageInMonths <= 72)      return {'min': 106.1,'max':125.8,'label': '5-6 سنوات'};
  if (ageInMonths <= 84)      return {'min': 111.2,'max':132.2,'label': '6-7 سنوات'};
  if (ageInMonths <= 96)      return {'min': 116.0,'max':137.9,'label': '7-8 سنوات'};
  if (ageInMonths <= 108)     return {'min': 120.5,'max':143.6,'label': '8-9 سنوات'};
  if (ageInMonths <= 120)     return {'min': 124.9,'max':149.0,'label': '9-10 سنوات'};
  if (ageInMonths <= 132)     return {'min': 129.5,'max':154.5,'label': '10-11 سنة'};
  if (ageInMonths <= 144)     return {'min': 134.5,'max':159.5,'label': '11-12 سنة'};
  if (ageInMonths <= 156)     return {'min': 139.5,'max':165.0,'label': '12-13 سنة'};
  if (ageInMonths <= 168)     return {'min': 144.5,'max':169.8,'label': '13-14 سنة'};
  if (ageInMonths <= 180)     return {'min': 150.0,'max':174.1,'label': '14-15 سنة'};
  if (ageInMonths <= 192)     return {'min': 154.0,'max':177.0,'label': '15-16 سنة'};
  if (ageInMonths <= 204)     return {'min': 157.0,'max':179.0,'label': '16-17 سنة'};
  return                             {'min': 159.0,'max':180.5,'label': '17-18 سنة'};
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
    if (value < min * 0.85)     return {'msg': 'نقص حاد في الوزن', 'color': Colors.red[700]!, 'status': 'low'};
    if (value < min)            return {'msg': 'أقل من المعدل الطبيعي', 'color': Colors.orange, 'status': 'low'};
    if (value > max * 1.15)     return {'msg': 'زيادة واضحة في الوزن', 'color': Colors.orange[800]!, 'status': 'high'};
    if (value > max)            return {'msg': 'فوق المعدل الطبيعي', 'color': Colors.orange, 'status': 'high'};
    return                             {'msg': 'وزن طبيعي وصحي ✓', 'color': Colors.green[700]!, 'status': 'ok'};
  } else {
    if (value < min * 0.93)     return {'msg': 'قصر نمو ملحوظ', 'color': Colors.red[700]!, 'status': 'low'};
    if (value < min)            return {'msg': 'أقل من متوسط الطول', 'color': Colors.orange, 'status': 'low'};
    if (value > max * 1.07)     return {'msg': 'طول فوق المتوسط', 'color': Colors.blue[700]!, 'status': 'high'};
    if (value > max)            return {'msg': 'فوق المتوسط قليلاً', 'color': Colors.blue, 'status': 'high'};
    return                             {'msg': 'طول طبيعي وصحي ✓', 'color': Colors.green[700]!, 'status': 'ok'};
  }
}

/// تحقق من منطقية القياسات المدخلة قبل الحفظ
String? validateGrowthEntry(String type, double value, int ageInMonths) {
  if (type == 'height') {
    if (ageInMonths < 3 && value > 65)   return 'الطول يتجاوز حد الرضيع (< 65 سم)';
    if (ageInMonths < 12 && value > 90)  return 'الطول يتجاوز حد الرضيع (< 90 سم)';
    if (ageInMonths < 36 && value > 115) return 'الطول كبير جداً للعمر';
    if (value < 20 || value > 220)       return 'قيمة الطول غير منطقية (20–220 سم)';
  } else if (type == 'weight') {
    if (ageInMonths < 6 && value > 12)   return 'الوزن كبير جداً لرضيع (< 12 كجم)';
    if (ageInMonths < 12 && value > 16)  return 'الوزن يتجاوز حد الرضيع (< 16 كجم)';
    if (value < 0.5 || value > 200)      return 'قيمة الوزن غير منطقية (0.5–200 كجم)';
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

  /// عمر الطفل بالشهور — القيمة المخزَّنة في DB هي دائماً بالشهور
  /// (تم ضمان ذلك في admin_member_management_screen.dart)
  /// لا حاجة لأي تحويل هنا — نستخدم member.age مباشرة.
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
      final filtered = vitals.where((v) => v.type == 'height' || v.type == 'weight').toList();
      setState(() { _vitals = filtered; _loading = false; });
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

  void _showAddDialog() {
    final hCtrl = TextEditingController();
    final wCtrl = TextEditingController();

    final ageM = _ageInMonths;
    final wRange = whoWeightRange(ageM);
    final hRange = whoHeightRange(ageM);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل بيانات النمو', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نطاق WHO المرجعي
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.tealLight, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المعدل الطبيعي — ${wRange['label']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
                  const SizedBox(height: 4),
                  Text('الوزن: ${wRange['min']} – ${wRange['max']} كجم   |   الطول: ${hRange['min']} – ${hRange['max']} سم',
                      style: const TextStyle(fontSize: 11, color: AppColors.grey600)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: hCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'الطول (سم)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.straighten, color: AppColors.teal),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: wCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'الوزن (كجم)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.scale, color: AppColors.teal),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final hVal = double.tryParse(hCtrl.text.trim());
              final wVal = double.tryParse(wCtrl.text.trim());

              if (hVal == null && wVal == null) {
                _showError('أدخل قيمة واحدة على الأقل');
                return;
              }

              // تحقق منطقي بناءً على العمر
              if (hVal != null) {
                final err = validateGrowthEntry('height', hVal, _ageInMonths);
                if (err != null) { _showError(err); return; }
              }
              if (wVal != null) {
                final err = validateGrowthEntry('weight', wVal, _ageInMonths);
                if (err != null) { _showError(err); return; }
              }

              final nav = Navigator.of(ctx);
              try {
                final familyId = await _authService.familyId;
                if (!mounted || familyId == null) return;

                if (hVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId, memberId: widget.member.id!,
                    type: 'height', value: hVal, unit: 'سم',
                  ));
                }
                if (wVal != null) {
                  await _repo.insertVital(VitalRecord(
                    familyId: familyId, memberId: widget.member.id!,
                    type: 'weight', value: wVal, unit: 'كجم',
                  ));
                }
                nav.pop();
                _loadVitals();
              } catch (e) {
                _showError('تعذّر الحفظ: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// يعرض بطاقة نطاق WHO المرجعية في أعلى الشاشة
  Widget _buildWhoReferenceCard() {
    final ageM = _ageInMonths;
    final wRange = whoWeightRange(ageM);
    final hRange = whoHeightRange(ageM);
    final String ageLabel;
    if (ageM < 24) {
      ageLabel = '$ageM شهراً';
    } else {
      ageLabel = '${(ageM / 12).toStringAsFixed(1)} سنة';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.teal.withValues(alpha: 0.9), const Color(0xFF004D40)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('معايير منظمة الصحة العالمية — $ageLabel',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                // رأس ملف الطفل
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                        child: Icon(t.icon, color: t.color),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.member.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          _ageInMonths < 24
                              ? '$_ageInMonths شهراً'
                              : '${(_ageInMonths / 12).toStringAsFixed(0)} سنة',
                          style: const TextStyle(color: AppColors.grey600, fontSize: 13),
                        ),
                      ]),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),

                // ── بطاقة معايير WHO المرجعية ──────────────────────────────
                SliverToBoxAdapter(child: _buildWhoReferenceCard()),

                // ── قائمة سجلات النمو ──────────────────────────────────────
                if (_vitals.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Column(children: [
                        Icon(Icons.show_chart_rounded, size: 64, color: AppColors.grey200),
                        const SizedBox(height: 16),
                        const Text('لا توجد سجلات نمو بعد',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.grey600)),
                        const SizedBox(height: 8),
                        const Text('اضغط + لتسجيل الطول والوزن',
                            style: TextStyle(fontSize: 13, color: AppColors.grey500)),
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
                        final vital = _vitals[index];
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
                              color: statusColor.withValues(alpha: 0.25), width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isHeight ? Icons.straighten_rounded : Icons.scale_rounded,
                                    color: statusColor, size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isHeight ? 'الطول' : 'الوزن',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.grey900)),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(feedback['msg'] as String,
                                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    ]),
                                  ],
                                )),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(
                                    '${vital.value} ${vital.unit}',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: statusColor),
                                  ),
                                  Text(
                                    vital.recordedAt?.toString().split('T').first ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.grey500),
                                  ),
                                ]),
                              ]),
                              const SizedBox(height: 10),
                              // شريط النطاق الطبيعي
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
  const _WhoRangeChip({required this.icon, required this.label, required this.range});

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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Text(range, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
    required this.value, required this.min,
    required this.max, required this.color, required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    // حساب موضع القيمة على الشريط (0.0 – 1.0)
    final double rangeSpan = (max - min) * 1.4; // نوسّع النطاق قليلاً للعرض
    final double barMin = min - rangeSpan * 0.2;
    final double barMax = max + rangeSpan * 0.2;
    final double position = ((value - barMin) / (barMax - barMin)).clamp(0.0, 1.0);
    final double normalStart = ((min - barMin) / (barMax - barMin)).clamp(0.0, 1.0);
    final double normalEnd   = ((max - barMin) / (barMax - barMin)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$min $unit', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
          Text('النطاق الطبيعي', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
          Text('$max $unit', style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        ]),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(clipBehavior: Clip.none, children: [
            // الخلفية
            Container(height: 6, decoration: BoxDecoration(
              color: AppColors.grey200, borderRadius: BorderRadius.circular(3))),
            // النطاق الطبيعي (أخضر)
            Positioned(
              left: w * normalStart,
              width: w * (normalEnd - normalStart),
              top: 0,
              child: Container(height: 6, decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3))),
            ),
            // المؤشر
            Positioned(
              left: (w * position - 5).clamp(0.0, w - 10),
              top: -3,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
            ),
          ]);
        }),
      ],
    );
  }
}