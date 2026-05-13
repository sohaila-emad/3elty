import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';
import '../services/notification_helper.dart';

class MedicationsScreen extends StatefulWidget {
  final FamilyMember member;

  const MedicationsScreen({super.key, required this.member});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<MedicationRecord> _medications = [];
  bool _loading = true;

  // ── دالة مساعدة: تنسيق الوقت كنص ─────────────────────────────────────────
  static String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    if (widget.member.id == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      setState(() => _loading = true);
      final meds = await _repo.getMedicationsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() {
        _medications = meds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل الأدوية: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إضافة دواء جديد
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showAddMedicationDialog() async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    int reminderHour = 8;
    int reminderMinute = 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 20),
              const Text('إضافة دواء',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                  controller: nameCtrl,
                  decoration: _inputDeco('اسم الدواء', 'مثال: أسبرين')),
              const SizedBox(height: 14),
              TextField(
                  controller: doseCtrl,
                  decoration: _inputDeco('الجرعة', 'مثال: ٥٠٠ مجم')),
              const SizedBox(height: 14),
              TextField(
                  controller: freqCtrl,
                  decoration:
                      _inputDeco('التكرار', 'مثال: مرتين يومياً')),
              const SizedBox(height: 14),
              const Text('وقت التذكير',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey600)),
              const SizedBox(height: 8),
              _timePickerButton(
                hour: reminderHour,
                minute: reminderMinute,
                parentContext: ctx,
                onChanged: (h, m) => setModal(() {
                  reminderHour = h;
                  reminderMinute = m;
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        doseCtrl.text.trim().isEmpty ||
                        freqCtrl.text.trim().isEmpty) {
                      _showError('يرجى ملء جميع الحقول');
                      return;
                    }
                    if (widget.member.id == null) {
                      _showError('لم يُحفظ الفرد بعد');
                      return;
                    }
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final familyId = await _authService.familyId;
                      if (!mounted) return;
                      if (familyId == null) {
                        _showError(
                            'لم يتم العثور على العائلة. يرجى تسجيل الدخول مجدداً.');
                        return;
                      }

                      // insertMedication generates a stable ID and returns
                      // the saved record — id is guaranteed non-null
                      final saved = await _repo.insertMedication(
                        MedicationRecord(
                          familyId: familyId,
                          memberId: widget.member.id!,
                          name: nameCtrl.text.trim(),
                          dose: doseCtrl.text.trim(),
                          frequency: freqCtrl.text.trim(),
                          timeOfDay:
                              _formatTime(reminderHour, reminderMinute),
                          reminderHour: reminderHour,
                          reminderMinute: reminderMinute,
                        ),
                      );

                      // Use the record's own stable ID as the notification key
                      await NotificationHelper.instance
                          .scheduleMedicationReminder(
                        medicationId: saved.id!,
                        medicationName: saved.name,
                        memberName: widget.member.name,
                        hour: saved.reminderHour,
                        minute: saved.reminderMinute,
                      );

                      if (!mounted) return;
                      nav.pop();
                      await _loadMedications();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text(
                            'تمت إضافة ${saved.name} وجُدول التذكير ✓',
                            style:
                                const TextStyle(color: Colors.white)),
                      ));
                    } catch (e) {
                      _showError('تعذّر إضافة الدواء: $e');
                    }
                  },
                  child: const Text('إضافة الدواء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // تعديل دواء موجود
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showEditMedicationDialog(MedicationRecord med) async {
    if (med.id == null) {
      _showError('لا يمكن تعديل هذا الدواء: معرّفه غير موجود');
      return;
    }

    final nameCtrl = TextEditingController(text: med.name);
    final doseCtrl = TextEditingController(text: med.dose);
    final freqCtrl = TextEditingController(text: med.frequency);
    int reminderHour = med.reminderHour;
    int reminderMinute = med.reminderMinute;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              const SizedBox(height: 20),
              const Text('تعديل الدواء',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextField(
                  controller: nameCtrl,
                  decoration: _inputDeco('اسم الدواء', 'مثال: أسبرين')),
              const SizedBox(height: 14),
              TextField(
                  controller: doseCtrl,
                  decoration: _inputDeco('الجرعة', 'مثال: ٥٠٠ مجم')),
              const SizedBox(height: 14),
              TextField(
                  controller: freqCtrl,
                  decoration:
                      _inputDeco('التكرار', 'مثال: مرتين يومياً')),
              const SizedBox(height: 14),
              const Text('وقت التذكير',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey600)),
              const SizedBox(height: 8),
              _timePickerButton(
                hour: reminderHour,
                minute: reminderMinute,
                parentContext: ctx,
                onChanged: (h, m) => setModal(() {
                  reminderHour = h;
                  reminderMinute = m;
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        doseCtrl.text.trim().isEmpty ||
                        freqCtrl.text.trim().isEmpty) {
                      _showError('يرجى ملء جميع الحقول');
                      return;
                    }
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final timeChanged =
                          reminderHour != med.reminderHour ||
                              reminderMinute != med.reminderMinute;

                      // Cancel old notification before rescheduling if time changed
                      if (timeChanged) {
                        await NotificationHelper.instance
                            .cancelMedicationReminder(med.id!);
                      }

                      final updated = med.copyWith(
                        name: nameCtrl.text.trim(),
                        dose: doseCtrl.text.trim(),
                        frequency: freqCtrl.text.trim(),
                        timeOfDay:
                            _formatTime(reminderHour, reminderMinute),
                        reminderHour: reminderHour,
                        reminderMinute: reminderMinute,
                      );

                      await _repo.updateMedicationRecord(updated);

                      // Always reschedule so notification body stays in sync
                      await NotificationHelper.instance
                          .scheduleMedicationReminder(
                        medicationId: updated.id!,
                        medicationName: updated.name,
                        memberName: widget.member.name,
                        hour: updated.reminderHour,
                        minute: updated.reminderMinute,
                      );

                      if (!mounted) return;
                      nav.pop();
                      await _loadMedications();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Text('تم تحديث ${updated.name} ✓',
                            style:
                                const TextStyle(color: Colors.white)),
                      ));
                    } catch (e) {
                      _showError('تعذّر تحديث الدواء: $e');
                    }
                  },
                  child: const Text('حفظ التعديلات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // حذف دواء
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _deleteMedication(MedicationRecord med) async {
    if (med.id == null) {
      _showError('لا يمكن حذف هذا الدواء: معرّفه غير موجود');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الدواء؟'),
        content: Text('هل تريد حذف ${med.name}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // 1. Cancel notification using the record's own stable ID
      await NotificationHelper.instance
          .cancelMedicationReminder(med.id!);
      // 2. Delete from DB
      await _repo.deleteMedication(med.id!);
      // 3. Refresh
      await _loadMedications();
      if (!mounted) return;
      _showSuccess('تم حذف ${med.name} وإلغاء التذكير');
    } catch (e) {
      _showError('تعذّر الحذف: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // مساعدات UI مشتركة
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _sheetHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.grey200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _timePickerButton({
    required int hour,
    required int minute,
    required BuildContext parentContext,
    required void Function(int h, int m) onChanged,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showTimePicker(
            context: parentContext,
            initialTime: TimeOfDay(hour: hour, minute: minute),
            helpText: 'اختر وقت التذكير',
          );
          if (picked != null) onChanged(picked.hour, picked.minute);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.grey200),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  color: AppColors.teal, size: 20),
              const SizedBox(width: 10),
              Text(
                _formatTime(hour, minute),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey900,
                ),
              ),
              const Spacer(),
              const Text('تغيير',
                  style: TextStyle(fontSize: 13, color: AppColors.teal)),
            ],
          ),
        ),
      );

  InputDecoration _inputDeco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
      );

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('الأدوية'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                // ── Member header ─────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.bgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(t.icon, color: t.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.member.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey900,
                                )),
                            Text(t.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: t.color,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── List ─────────────────────────────────────────────────
                Expanded(
                  child: _medications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.medication_rounded,
                                  size: 64, color: AppColors.grey200),
                              SizedBox(height: 16),
                              Text('لا توجد أدوية بعد',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey600,
                                  )),
                              SizedBox(height: 8),
                              Text('أضف دواءً للبدء',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.grey600)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _medications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final med = _medications[i];
                            return _MedicationCard(
                              med: med,
                              onEdit: () =>
                                  _showEditMedicationDialog(med),
                              onDelete: () => _deleteMedication(med),
                              formatTime: _formatTime,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedicationDialog,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة دواء'),
      ),
    );
  }
}

// ─── بطاقة الدواء ─────────────────────────────────────────────────────────────
class _MedicationCard extends StatelessWidget {
  final MedicationRecord med;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(int, int) formatTime;

  const _MedicationCard({
    required this.med,
    required this.onEdit,
    required this.onDelete,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey900,
                            )),
                        const SizedBox(height: 4),
                        Text(med.dose,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.grey600)),
                      ],
                    ),
                  ),
                  // Edit icon
                  const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.grey600),
                  const SizedBox(width: 8),
                  // Time badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text(
                          formatTime(
                              med.reminderHour, med.reminderMinute),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('كل ${med.frequency}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.grey600)),
                  const Spacer(),
                  Text('اضغط للتعديل • اضغط مطولاً للحذف',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey600.withOpacity(0.6))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}