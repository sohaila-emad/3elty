import 'package:flutter/material.dart';
import '../main.dart';
import '../services/firestore_service.dart';
import '../utils/error_handler.dart';

/// شاشة إدارة أفراد العائلة - للمشرفين فقط (إضافة / تعديل / حذف)
class AdminMemberManagementScreen extends StatefulWidget {
  const AdminMemberManagementScreen({super.key});

  @override
  State<AdminMemberManagementScreen> createState() =>
      _AdminMemberManagementScreenState();
}

class _AdminMemberManagementScreenState
    extends State<AdminMemberManagementScreen> {
  final _firestoreService = FirestoreService.instance;

  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  // خيارات أنواع الملفات الشخصية
  static const List<Map<String, dynamic>> _profileOptions = [
    {'type': 'child', 'label': 'طفل', 'icon': Icons.child_care_rounded},
    {'type': 'elderly', 'label': 'كبير سن', 'icon': Icons.elderly_rounded},
    {
      'type': 'pregnant',
      'label': 'حامل',
      'icon': Icons.pregnant_woman_rounded
    },
    {
      'type': 'chronic',
      'label': 'مريض مزمن',
      'icon': Icons.monitor_heart_outlined
    },
    {'type': 'adult', 'label': 'بالغ', 'icon': Icons.person_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final members = await _firestoreService.getFamilyMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ErrorHandler.showError(context, 'تعذّر تحميل الأفراد: $e');
    }
  }

  // ── Age thresholds ────────────────────────────────────────────────────────
  // child   : 0 – 23 months  (stored as months when ageInMonths = true)
  // adult   : 2 years (24 m) – 54 years
  // elderly : 55 – 100 years
  // pregnant: 15 – 45 years  (unchanged)
  // chronic : 0 – 100 years  (no restriction)

  /// Validates the entered age value against the selected profile type.
  /// [ageValue] is always the raw number the user typed.
  /// [ageInMonths] is true only when the child toggle is set to "months".
  /// Returns an error message string, or null if valid.
  String? _validateAge({
    required String selectedType,
    required int ageValue,
    required bool ageInMonths,
  }) {
    // Convert to years (fractional) for uniform comparison
    final double ageYears = ageInMonths ? ageValue / 12.0 : ageValue.toDouble();

    switch (selectedType) {
      case 'child':
        // يقبل 0–216 شهراً (18 سنة) أو 0–18 سنة
        if (ageInMonths) {
          if (ageValue < 0 || ageValue > 216) {
            return 'عمر الطفل بالشهور يجب أن يكون بين 0 و 216 شهراً (18 سنة).';
          }
        } else {
          if (ageValue < 0 || ageValue > 18) {
            return 'عمر الطفل بالسنوات يجب أن يكون بين 0 و 18 سنة.';
          }
        }
        return null;

      case 'elderly':
        if (ageYears < 55 || ageYears > 100) {
          return 'عمر كبير السن يجب أن يكون بين 55 و 100 سنة.';
        }
        return null;

      case 'pregnant':
        if (ageYears < 15 || ageYears > 45) {
          return 'عمر الحامل يجب أن يكون بين 15 و 45 سنة.';
        }
        return null;

      case 'adult':
        if (ageYears < 21|| ageYears >100){
          return 'عمر البالغ يجب أن يكون بين 2 و 54 سنة.';
        }
        return null;

      case 'chronic':
        if (ageYears < 0 || ageYears > 100) {
          return 'العمر يجب أن يكون بين 0 و 100.';
        }
        return null;

      default:
        return null;
    }
  }

  Future<void> _showAddMemberSheet() async {
    final nameCtrl = TextEditingController();
    final ageCtrl  = TextEditingController();
    String selectedType  = 'adult';
    bool   ageInMonths   = false; // only relevant for child

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('إضافة فرد جديد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // ── الاسم ────────────────────────────────────────────────
                _inputField(nameCtrl, 'الاسم الكامل', 'مثال: أحمد محمد علي'),
                const SizedBox(height: 14),

                // ── العمر + toggle بالشهور (للطفل فقط) ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _inputField(
                        ageCtrl,
                        selectedType == 'child' && ageInMonths
                            ? 'العمر بالشهور'
                            : 'العمر بالسنوات',
                        selectedType == 'child' && ageInMonths
                            ? 'مثال: 6'
                            : 'مثال: 35',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    if (selectedType == 'child') ...[
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('شهور',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.grey600)),
                          const SizedBox(height: 4),
                          Switch(
                            value: ageInMonths,
                            activeColor: AppColors.teal,
                            onChanged: (v) {
                              setModalState(() {
                                ageInMonths = v;
                                ageCtrl.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),

                // ── hint النطاق حسب النوع ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: Text(
                    _ageHint(selectedType, ageInMonths),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grey400),
                  ),
                ),
                const SizedBox(height: 14),

                // ── نوع الملف الشخصي ─────────────────────────────────────
                const Text('نوع الملف الشخصي',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _profileOptions.map((opt) {
                    final selected = selectedType == opt['type'];
                    final pt = ProfileType.values
                        .firstWhere((p) => p.name == opt['type']);
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        selectedType = opt['type'] as String;
                        // reset months toggle when switching away from child
                        if (selectedType != 'child') ageInMonths = false;
                        ageCtrl.clear();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? pt.color : AppColors.grey100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? pt.color : AppColors.grey200,
                          ),
                        ),
                        child:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(opt['icon'] as IconData,
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : AppColors.grey600),
                          const SizedBox(width: 6),
                          Text(opt['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.grey600)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── زر الإضافة ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة الفرد'),
                    onPressed: () async {
                      final name     = nameCtrl.text.trim();
                      final ageValue = int.tryParse(ageCtrl.text.trim());

                      // 1. تحقق من الحقول الأساسية
                      if (name.isEmpty || ageValue == null) {
                        ErrorHandler.showError(
                            context, 'يرجى تعبئة الاسم والعمر بشكل صحيح');
                        return;
                      }

                      // 2. تحقق من النطاق حسب نوع الملف
                      final ageError = _validateAge(
                        selectedType: selectedType,
                        ageValue: ageValue,
                        ageInMonths: ageInMonths,
                      );
                      if (ageError != null) {
                        ErrorHandler.showError(context, ageError);
                        return;
                      }

                      // 3. حفظ العمر — المبدأ الموحَّد (Option A):
                      //    • الطفل دائماً يُخزَّن بالشهور في DB
                      //      - إذا اختار المستخدم "شهور": نحفظ القيمة مباشرة
                      //      - إذا اختار "سنوات": نضرب × 12 قبل الحفظ
                      //    • باقي الأنواع: نحفظ بالسنوات كما هو
                      final int ageToSave = (selectedType == 'child' && !ageInMonths)
                          ? ageValue * 12   // تحويل سنوات → شهور للطفل
                          : ageValue;       // شهور مباشرة أو سنوات لباقي الأنواع

                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);

                      // ── Optimistic instant update ─────────────────────────
                      // Add a temporary entry to _members immediately so the
                      // user sees the new card the moment they tap Save —
                      // before the Firestore round-trip completes.
                      final optimisticEntry = {
                        'id': '__optimistic__',
                        'name': name,
                        'age': ageToSave,
                        'profile_type': selectedType,
                      };
                      setState(() => _members.add(optimisticEntry));
                      navigator.pop(); // close the sheet right away

                      // Show success SnackBar immediately
                      messenger.showSnackBar(SnackBar(
                        backgroundColor: AppColors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        content: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text('تمت إضافة $name بنجاح ✓',
                              style: const TextStyle(color: Colors.white)),
                        ]),
                      ));

                      // ── Background Firestore write + reconcile ────────────
                      // Run the actual write after the sheet is closed.
                      // _loadMembers() replaces the optimistic entry with the
                      // real Firestore document (correct ID, server timestamps).
                      try {
                        await _firestoreService.addFamilyMember(
                          name: name,
                          age: ageToSave,
                          profileType: selectedType,
                        );
                        if (!mounted) return;
                        // Reconcile: replace optimistic entry with real data
                        _loadMembers();
                      } catch (e) {
                        if (!mounted) return;
                        // Roll back: remove the optimistic entry on failure
                        setState(() => _members
                            .removeWhere((m) => m['id'] == '__optimistic__'));
                        messenger.showSnackBar(SnackBar(
                          backgroundColor: AppColors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          content: Row(children: [
                            const Icon(Icons.error_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('تعذّر الإضافة: $e',
                                style: const TextStyle(color: Colors.white))),
                          ]),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns a short hint describing the allowed age range for a profile type.
  String _ageHint(String type, bool ageInMonths) {
    switch (type) {
      case 'child':
        return ageInMonths
            ? 'النطاق المسموح: 0 – 216 شهراً (18 سنة)'
            : 'النطاق المسموح: 0 – 18 سنة';
      case 'elderly':
        return 'النطاق المسموح: 55 – 100 سنة';
      case 'pregnant':
        return 'النطاق المسموح: 15 – 45 سنة';
      case 'adult':
        return 'النطاق المسموح: 2 – 54 سنة';
      case 'chronic':
        return 'النطاق المسموح: 0 – 100 سنة';
      default:
        return '';
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف ${member['name']}؟',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
            'سيتم حذف جميع بياناته الصحية نهائياً.',
            style: TextStyle(
                fontSize: 14, color: AppColors.grey600, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteFamilyMember(member['id'] as String);
      if (!mounted) return;
      _loadMembers();
      ErrorHandler.showSuccess(context, 'تم حذف ${member['name']}');
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, 'تعذّر الحذف: $e');
    }
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('إدارة أفراد العائلة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : _members.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                          color: AppColors.tealLight,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.group_add_rounded,
                          size: 48, color: AppColors.teal),
                    ),
                    const SizedBox(height: 24),
                    const Text('لا يوجد أفراد بعد',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('اضغط الزر أدناه لإضافة أول فرد.',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.grey600)),
                  ],
                ))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  separatorBuilder: (_, _x) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = _members[i];
                    final pt = ProfileType.values.firstWhere(
                      (p) => p.name == (m['profile_type'] ?? 'adult'),
                      orElse: () => ProfileType.adult,
                    );
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: pt.bgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                Icon(pt.icon, color: pt.color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(m['name'] ?? '—',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.grey900)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pt.bgColor,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(pt.label,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: pt.color)),
                                    ),
                                    const SizedBox(width: 8),
                                    Builder(builder: (context) {
                                      final rawAge = m['age'] as int? ?? 0;
                                      final isChild = (m['profile_type'] ?? '') == 'child';
                                      final String ageLabel;
                                      if (isChild) {
                                        // الطفل مخزَّن بالشهور دائماً
                                        ageLabel = rawAge >= 12
                                            ? '${rawAge ~/ 12} سنة'
                                            : '$rawAge شهراً';
                                      } else {
                                        ageLabel = '$rawAge سنة';
                                      }
                                      return Text(ageLabel,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.grey600));
                                    }),
                                  ]),
                                ]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.red),
                            onPressed: () => _confirmDelete(m),
                            tooltip: 'حذف',
                          ),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberSheet,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة فرد'),
      ),
    );
  }
}