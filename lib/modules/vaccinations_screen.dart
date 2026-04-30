import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/notification_helper.dart';

class VaccinationsScreen extends StatefulWidget {
  final FamilyMember member;
  const VaccinationsScreen({super.key, required this.member});

  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen> {
  final _repo = AppRepository.instance;
  List<dynamic> _vaccinations = [];
  bool _loading = true;

  // Egypt MOH Vaccination Schedule (Age in months)
  final List<Map<String, dynamic>> _mohSchedule = [
    {'vaccine': 'BCG', 'age': 'عند الولادة', 'ageMonths': 0},
    {'vaccine': 'Hepatitis B (Birth Dose)', 'age': 'عند الولادة', 'ageMonths': 0},
    {'vaccine': 'DPT 1', 'age': 'شهران', 'ageMonths': 2},
    {'vaccine': 'Polio 1', 'age': 'شهران', 'ageMonths': 2},
    {'vaccine': 'Hepatitis B 1', 'age': 'شهران', 'ageMonths': 2},
    {'vaccine': 'DPT 2', 'age': '٤ أشهر', 'ageMonths': 4},
    {'vaccine': 'Polio 2', 'age': '٤ أشهر', 'ageMonths': 4},
    {'vaccine': 'Hepatitis B 2', 'age': '٤ أشهر', 'ageMonths': 4},
    {'vaccine': 'DPT 3', 'age': '٦ أشهر', 'ageMonths': 6},
    {'vaccine': 'Polio 3', 'age': '٦ أشهر', 'ageMonths': 6},
    {'vaccine': 'Hepatitis B 3', 'age': '٦ أشهر', 'ageMonths': 6},
    {'vaccine': 'MMR', 'age': '١٢ شهراً', 'ageMonths': 12},
    {'vaccine': 'DPT Booster 1', 'age': '١٨ شهراً', 'ageMonths': 18},
    {'vaccine': 'Polio Booster', 'age': '١٨ شهراً', 'ageMonths': 18},
  ];

  @override
  void initState() {
    super.initState();
    _loadVaccinations();
  }

  Future<void> _loadVaccinations() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final vaxes = await _repo.getVaccinationsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _vaccinations = vaxes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل التطعيمات: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), content: Text(msg, style: const TextStyle(color: Colors.white))));

  // ── تسجيل تطعيم جديد ─────────────────────────────────────────────────────
  Future<void> _showAddVaccinationDialog() async {
    String? selectedVaccine;

    // قائمة التطعيمات غير المستلمة بعد
    final pending = _mohSchedule.where((s) {
      final vaccine = s['vaccine'] as String;
      return !_vaccinations.any((v) => v.vaccineName.contains(vaccine));
    }).toList();

    if (pending.isEmpty) {
      _showSuccess('ما شاء الله! تم استلام جميع التطعيمات المقررة 🎉');
      return;
    }

    selectedVaccine = pending.first['vaccine'] as String;
    final clinicCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('تسجيل تطعيم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              const Text('اختر التطعيم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey600)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedVaccine,
                isExpanded: true,
                items: pending.map((s) => DropdownMenuItem<String>(
                  value: s['vaccine'] as String,
                  child: Text('${s['vaccine']} — ${s['age']}'),
                )).toList(),
                onChanged: (v) => setModal(() => selectedVaccine = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: clinicCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المركز الطبي',
                  hintText: 'اختياري',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (selectedVaccine == null || widget.member.id == null) return;
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _repo.insertVaccination(VaccinationRecord(
                        memberId: widget.member.id!,
                        vaccineName: selectedVaccine!,
                        clinicName: clinicCtrl.text.isEmpty ? null : clinicCtrl.text.trim(),
                        receivedAt: DateTime.now().toIso8601String().substring(0, 10),
                        isReceived: true,
                      ));

                      // ── إرسال إشعار تأكيد التطعيم ────────────────────────
                      await NotificationHelper.instance.notifyVaccinationLogged(
                        vaccineName: selectedVaccine!,
                        memberName: widget.member.name,
                      );

                      if (!mounted) return;
                      navigator.pop();
                      _loadVaccinations();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Text('تم تسجيل $selectedVaccine بنجاح ✓', style: const TextStyle(color: Colors.white)),
                      ));
                    } catch (e) {
                      _showError('تعذّر التسجيل: $e');
                    }
                  },
                  child: const Text('تسجيل التطعيم', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('التطعيمات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(t.icon, color: t.color, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)), Text('${widget.member.age} سنة', style: const TextStyle(fontSize: 13, color: AppColors.grey600))])),
                ])),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mohSchedule.length,
                    itemBuilder: (_, i) {
                      final schedule = _mohSchedule[i];
                      final vaccine = schedule['vaccine'] as String;
                      final age = schedule['age'] as String;
                      
                      // Check if this vaccination is in the logged vaccinations
                      final logged = _vaccinations.any((v) => v.vaccineName.contains(vaccine));
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: logged ? AppColors.green.withValues(alpha: 0.1) : AppColors.grey100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    logged ? Icons.check_circle : Icons.circle_outlined,
                                    color: logged ? AppColors.green : AppColors.grey400,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(vaccine, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                                      Text(age, style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
                                    ],
                                  ),
                                ),
                                if (logged)
                                  Chip(
                                    label: const Text('تم التطعيم', style: TextStyle(fontSize: 12, color: Colors.white)),
                                    backgroundColor: AppColors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVaccinationDialog,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تسجيل تطعيم'),
      ),
    );
  }
}
