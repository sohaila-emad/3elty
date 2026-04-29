import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class VitalsScreen extends StatefulWidget {
  final FamilyMember member;

  const VitalsScreen({super.key, required this.member});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<dynamic> _vitals = [];
  bool _loading = true;

  static const List<String> _vitalTypes = [
    'ضغط الدم (الانقباضي)',
    'ضغط الدم (الانبساطي)',
    'سكر الدم',
    'معدل ضربات القلب',
    'درجة الحرارة',
  ];

  @override
  void initState() {
    super.initState();
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final vitals = await _repo.getVitalsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _vitals = vitals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل العلامات الحيوية: $e');
    }
  }

  Future<void> _showAddVitalDialog() async {
    final valueCtrl = TextEditingController();
    String selectedType = _vitalTypes[0];
    String selectedUnit = 'mmHg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text('تسجيل علامة حيوية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              const Text('النوع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey600)),
              DropdownButton<String>(
                value: selectedType,
                isExpanded: true,
                items: _vitalTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setModalState(() => selectedType = v ?? selectedType),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('القيمة', 'مثال: ١٢٠'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton( 
                  onPressed: () async {
                    final double? val = double.tryParse(valueCtrl.text);
                    
                    if (val == null || widget.member.id == null) {
                      _showError('يرجى إدخال رقم صحيح');
                      return;
                    }

                    // 1. منطق الرفض (Unreasonable Values) - أرقام مستحيلة فيزيائياً
                    if (selectedType == 'درجة الحرارة' && (val > 45 || val < 32)) {
                      _showError('درجة حرارة غير منطقية! يرجى التأكد.');
                      return;
                    }
                    if (selectedType == 'سكر الدم' && (val > 600 || val < 20)) {
                      _showError('قيمة سكر غير معقولة طبياً!');
                      return;
                    }
                    if (selectedType.contains('ضغط الدم') && (val > 260 || val < 40)) {
                      _showError('قيمة ضغط دم مستحيلة!');
                      return;
                    }

                    // 2. منطق التنبيه (Normal Range Alerts) - أرقام تحتاج انتباه
                    String? warning;
                    if (selectedType == 'درجة الحرارة' && val >= 38) {
                      warning = 'انتباه: درجة الحرارة مرتفعة (حمى)!';
                    } else if (selectedType == 'ضغط الدم (الانقباضي)' && val > 140) {
                      warning = 'انتباه: ضغط الدم الانقباضي مرتفع.';
                    } else if (selectedType == 'سكر الدم' && (val > 180 || val < 70)) {
                      warning = 'انتباه: مستوى السكر خارج النطاق الطبيعي.';
                    }

                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    
                    try {
                      final familyId = await _authService.familyId;
                      if (!mounted) return;
                      if (familyId == null) {
                        _showError('لم يتم العثور على العائلة.');
                        return;
                      }

                      await _repo.insertVital(VitalRecord(
                        familyId: familyId,
                        memberId: widget.member.id!,
                        type: selectedType,
                        value: val,
                        unit: selectedUnit,
                      ));

                      if (!mounted) return;
                      navigator.pop();
                      _loadVitals();

                      // إظهار تنبيه لو الرقم غير طبيعي، أو رسالة نجاح عادية
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: warning != null ? AppColors.orange : AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Text(warning ?? 'تم تسجيل العلامة الحيوية بنجاح'),
                      ));
                    } catch (e) {
                      _showError('فشل الحفظ: $e');
                    }
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

  InputDecoration _buildInputDecoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
  );

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('العلامات الحيوية')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(t.icon, color: t.color, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                    Text(t.label, style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w500)),
                  ])),
                ])),
                const Divider(height: 1),
                Expanded(
                  child: _vitals.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.favorite_rounded, size: 64, color: AppColors.grey200),
                    const SizedBox(height: 16),
                    const Text('لا توجد علامات حيوية بعد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.grey600)),
                  ]))
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vitals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final vital = _vitals[i];
                      return Material(color: Colors.white, borderRadius: BorderRadius.circular(12), child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(vital.type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                            Text('${vital.value} ${vital.unit}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.orange)),
                          ]),
                          const SizedBox(height: 8),
                          Text(vital.recordedAt ?? 'الآن', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                        ]),
                      ));
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddVitalDialog, backgroundColor: AppColors.teal, foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('تسجيل علامة')),
    );
  }
}
