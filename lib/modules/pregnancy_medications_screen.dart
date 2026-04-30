import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';
import '../services/notification_helper.dart';

// ─── نموذج تأكيد الجرعة اليومي ────────────────────────────────────────────────
class _DailyConfirmState {
  final Map<String, bool> _confirmed = {};
  bool isConfirmed(String medId) => _confirmed[medId] ?? false;
  void confirm(String medId) => _confirmed[medId] = true;
}

class PregnancyMedicationsScreen extends StatefulWidget {
  final FamilyMember member;
  const PregnancyMedicationsScreen({super.key, required this.member});

  @override
  State<PregnancyMedicationsScreen> createState() =>
      _PregnancyMedicationsScreenState();
}

class _PregnancyMedicationsScreenState
    extends State<PregnancyMedicationsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  final _confirmState = _DailyConfirmState();

  List<MedicationRecord> _medications = [];
  bool _loading = true;

  static const List<String> _tips = [
    'تذكري شرب كمية وفيرة من الماء عند تناول الحديد والكالسيوم لضمان امتصاص أفضل وتجنب الإمساك.',
    'حمض الفوليك مهم جداً في الثلث الأول — لا تفوّتي جرعة واحدة.',
    'خذي الحديد على معدة فارغة أو مع عصير برتقال لتحسين الامتصاص.',
    'تجنّبي أخذ الكالسيوم والحديد في نفس الوقت — فارقي بينهم ساعتين.',
    'الغثيان الصباحي؟ جرّبي أخذ الفيتامينات مع الأكل.',
  ];

  String get _todayTip => _tips[DateTime.now().day % _tips.length];

  static const List<String> _arabicMonths = [
    '', 'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.day} ${_arabicMonths[now.month]}';
  }

  final int _weekStreak = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.member.id == null) { setState(() => _loading = false); return; }
    try {
      setState(() => _loading = true);
      final meds = await _repo.getMedicationsForMember(widget.member.id!);
      if (!mounted) return;
      setState(() { _medications = meds; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('تعذّر تحميل الأدوية: $e');
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(msg, style: const TextStyle(color: Colors.white))));

  // ── حذف دواء — مفعّل للحامل بدون أي قيود ─────────────────────────────────
  Future<void> _deleteMedication(MedicationRecord med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('حذف ${med.name}؟',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('هل تريدين إيقاف هذا الدواء وحذف تذكيره؟',
            style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || med.id == null) return;
    try {
      await NotificationHelper.instance.cancelMedicationReminder(
          '${widget.member.id}_${med.name}');
      await _repo.deleteMedication(med.id!);
      if (!mounted) return;
      _load();
      _showSuccess('تم حذف ${med.name} وإلغاء التذكير');
    } catch (e) {
      if (!mounted) return;
      _showError('تعذّر الحذف: $e');
    }
  }

  // ── إضافة دواء ─────────────────────────────────────────────────────────────
  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    String selectedTime = 'الصباح';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('إضافة دواء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              // حقل اسم الدواء — واحد فقط (إصلاح التكرار السابق)
              TextField(controller: nameCtrl, decoration: _field('اسم الدواء', 'مثال: حمض الفوليك')),
              const SizedBox(height: 14),
              TextField(controller: doseCtrl, decoration: _field('الجرعة', 'مثال: ٥ مجم')),
              const SizedBox(height: 14),
              const Text('وقت الجرعة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grey600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['الصباح', 'الظهر', 'المساء', 'الليل'].map((t) => FilterChip(
                  label: Text(t),
                  selected: selectedTime == t,
                  selectedColor: _pink.withValues(alpha: 0.15),
                  checkmarkColor: _pink,
                  onSelected: (_) => setS(() => selectedTime = t),
                )).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _pink),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || doseCtrl.text.isEmpty || widget.member.id == null) {
                      _showError('يرجى ملء جميع الحقول'); return;
                    }
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final familyId = await _authService.familyId;
                      if (!mounted) return;
                      if (familyId == null) { _showError('لم يتم العثور على العائلة.'); return; }
                      final medName = nameCtrl.text.trim();
                      // insertMedication يُرجع String ID بعد إصلاح app_repository.dart
                      await _repo.insertMedication(MedicationRecord(
                        familyId: familyId, memberId: widget.member.id!,
                        name: medName, dose: doseCtrl.text.trim(),
                        frequency: 'يومياً', timeOfDay: selectedTime,
                      ));
                      await NotificationHelper.instance.scheduleMedicationReminder(
                        medicationId: '${widget.member.id}_$medName',
                        medicationName: medName,
                        memberName: widget.member.name,
                        timeOfDay: selectedTime,
                      );
                      if (!mounted) return;
                      navigator.pop();
                      _load();
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        content: Text('تمت إضافة $medName وجُدول التذكير ✓',
                            style: const TextStyle(color: Colors.white)),
                      ));
                    } catch (e) { _showError('تعذّر الإضافة: $e'); }
                  },
                  child: const Text('إضافة الدواء', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _field(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint, filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _pink, width: 2)),
  );

  static const _pink = Color(0xFFAD1457);

  int get _remainingCount {
    final confirmed = _medications.where((m) => m.id != null && _confirmState.isConfirmed(m.id!)).length;
    return _medications.length - confirmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  title: const Text('متابعة الحمل', style: TextStyle(color: Colors.white)),
                  actions: [
                    Padding(padding: const EdgeInsets.only(left: 12),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                      )),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateCard(label: _todayLabel),
                      const SizedBox(height: 12),
                      _WeeklyStreakCard(streak: _weekStreak),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('قائمة الأدوية',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.grey900)),
                            Text('$_remainingCount جرعات متبقية',
                                style: const TextStyle(fontSize: 13, color: _pink, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_medications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Column(children: [
                            Icon(Icons.medication_rounded, size: 56, color: AppColors.grey200),
                            const SizedBox(height: 12),
                            const Text('لا توجد أدوية بعد',
                                style: TextStyle(fontSize: 16, color: AppColors.grey600, fontWeight: FontWeight.w500)),
                          ])),
                        )
                      else
                        // Dismissible: اسحب لليسار لحذف الدواء
                        ..._medications.map((med) => Dismissible(
                          key: Key(med.id ?? med.name),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                              SizedBox(height: 4),
                              Text('حذف', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          confirmDismiss: (_) async {
                            await _deleteMedication(med);
                            return false;
                          },
                          child: _MedCard(
                            med: med,
                            confirmed: med.id != null && _confirmState.isConfirmed(med.id!),
                            onConfirm: () { if (med.id != null) setState(() => _confirmState.confirm(med.id!)); },
                            onDelete: () => _deleteMedication(med),
                          ),
                        )),
                      const SizedBox(height: 12),
                      _TipCard(tip: _todayTip),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة دواء'),
      ),
    );
  }
}

// ── بطاقة التاريخ ────────────────────────────────────────────────────────────
class _DateCard extends StatelessWidget {
  final String label;
  const _DateCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFAD1457), Color(0xFFC2185B)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اليوم إليكِ جدولك',
                style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

// ── بطاقة الالتزام الأسبوعي ──────────────────────────────────────────────────
class _WeeklyStreakCard extends StatelessWidget {
  final int streak;
  const _WeeklyStreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الالتزام الأسبوعي', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.star_rounded, color: Color(0xFFE65100), size: 14),
                  SizedBox(width: 4),
                  Text('ممتاز', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Text('$streak', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFFAD1457))),
            const SizedBox(width: 8),
            const Text('من ٧ أيام', style: TextStyle(fontSize: 14, color: AppColors.grey600)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: streak / 7, minHeight: 8,
                backgroundColor: AppColors.grey100,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFAD1457))),
          ),
          const SizedBox(height: 8),
          const Text('لقد أكملتِ معظم جرعاتك هذا الأسبوع، حافظي على هذا المستوى!',
              style: TextStyle(fontSize: 12, color: AppColors.grey500)),
        ],
      ),
    );
  }
}

// ── بطاقة الدواء ─────────────────────────────────────────────────────────────
class _MedCard extends StatelessWidget {
  final MedicationRecord med;
  final bool confirmed;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const _MedCard({
    required this.med, required this.confirmed,
    required this.onConfirm, required this.onDelete,
  });

  Color get _dotColor {
    switch (med.timeOfDay) {
      case 'الصباح': return const Color(0xFFFFB300);
      case 'الظهر':  return const Color(0xFFE65100);
      case 'المساء': return const Color(0xFF6A1B9A);
      default:       return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(med.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.grey900)),
              const SizedBox(height: 2),
              Text('${med.dose} — ${med.timeOfDay}', style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
            ])),
            // زر حذف مباشر
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
              onPressed: onDelete,
              tooltip: 'حذف الدواء',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 12),
          if (confirmed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_rounded, color: AppColors.green, size: 18),
                SizedBox(width: 6),
                Text('تم ✓', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFAD1457),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onConfirm,
                child: const Text('أخذته ✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── نصيحة اليوم ──────────────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final String tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFECB3), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFE65100), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('نصيحة اليوم',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
            const SizedBox(height: 4),
            Text(tip, style: const TextStyle(fontSize: 13, color: AppColors.grey900, height: 1.5)),
          ])),
        ],
      ),
    );
  }
}