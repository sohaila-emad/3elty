import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

// ── الشاشة الرئيسية ───────────────────────────────────────────────────────────
class UltrasoundLogScreen extends StatefulWidget {
  final FamilyMember member;
  const UltrasoundLogScreen({super.key, required this.member});

  @override
  State<UltrasoundLogScreen> createState() => _UltrasoundLogScreenState();
}

class _UltrasoundLogScreenState extends State<UltrasoundLogScreen> {
  final _authService = RemoteAuthService();
  final _repo = AppRepository.instance;
  // ignore: prefer_final_fields  — setState يضيف عناصر جديدة
  List<UltrasoundRecord> _records = [];
  bool _loading = true;

  static const _pink = Color(0xFFAD1457);

  static const List<String> _sessionTypes = [
    'الفصل الأول',
    'الفصل الثاني',
    'الفصل الثالث',
  ];

  static const List<String> _months = [
    'الشهر الأول', 'الشهر الثاني', 'الشهر الثالث',
    'الشهر الرابع', 'الشهر الخامس', 'الشهر السادس',
    'الشهر السابع', 'الشهر الثامن', 'الشهر التاسع',
  ];

  static const List<String> _calMonths = [
    '', 'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── تحميل السجلات من local DB ────────────────────────────────────────────
  // بما أن AppRepository مش عنده getUltrasoundsForMember بعد،
  // هنحفظ في SharedPreferences مؤقتاً مع in-memory list
  Future<void> _load() async {
    if (widget.member.id == null) return;
    setState(() => _loading = true);
    // استدعاء البيانات من المستودع بدلاً من القائمة المؤقتة
    final data = await _repo.getUltrasoundsForMember(widget.member.id!);
    if (!mounted) return;
    setState(() {
      _records = data;
      _loading = false;
    });
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  // ── dialog إضافة سونار ───────────────────────────────────────────────────
  Future<void> _showAddDialog() async {
    final doctorCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMonth = _months[0];
    String selectedSession = _sessionTypes[0];
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('إضافة متابعة صوتية',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // شهر الحمل
                const Text('شهر الحمل',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey600)),
                const SizedBox(height: 8),
                _dropdown(
                  value: selectedMonth,
                  items: _months,
                  onChanged: (v) => setS(() => selectedMonth = v!),
                ),
                const SizedBox(height: 14),

                // الفصل
                const Text('الفصل',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _sessionTypes.map((s) => GestureDetector(
                    onTap: () => setS(() => selectedSession = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedSession == s
                            ? _pink
                            : AppColors.grey100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedSession == s
                              ? _pink
                              : AppColors.grey200,
                        ),
                      ),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selectedSession == s
                                  ? Colors.white
                                  : AppColors.grey600)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 14),

                // التاريخ
                const Text('تاريخ الجلسة',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.grey600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: _pink),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setS(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.grey500, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        '${selectedDate.day} ${_calMonths[selectedDate.month]} ${selectedDate.year}',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.grey900),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // الدكتور
                _inputField(doctorCtrl, 'اسم الطبيب', 'مثال: د. مريم العتيبي'),
                const SizedBox(height: 14),

                // ملاحظات
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات الطبيب',
                    hintText: 'مثال: النمو طبيعي جداً...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.grey200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.grey200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _pink, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () async {
                      if (doctorCtrl.text.isEmpty) {
                        _showError('يرجى إدخال اسم الطبيب');
                        return;
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
                        final record = UltrasoundRecord(
                          familyId: familyId,
                          memberId: widget.member.id ?? '', // خليها قيمة نصية فاضية لو مفيش ID
                          monthLabel: selectedMonth,
                          sessionType: selectedSession,
                          date:
                              '${selectedDate.day} ${_calMonths[selectedDate.month]} ${selectedDate.year}',
                          doctor: doctorCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        await _repo.insertUltrasound(record);
                        await _load(); // إعادة تحميل القائمة بعد الحفظ
                        navigator.pop();
                        messenger.showSnackBar(SnackBar(
                          backgroundColor: AppColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          content: const Text('تمت إضافة المتابعة',
                              style: TextStyle(color: Colors.white)),
                        ));
                      } catch (e) {
                        _showError('تعذّر الإضافة: $e');
                      }
                    },
                    child: const Text('إضافة المتابعة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, String label, String hint) =>
      TextField(
        controller: c,
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
              borderSide: const BorderSide(color: _pink, width: 2)),
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : CustomScrollView(
              slivers: [
                // AppBar
                SliverAppBar(
                  pinned: true,
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  title: const Text('سجل المتابعات الصوتية',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: CircleAvatar(
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.25),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // ── بانر رحلة تمو الجنين ─────────────────────────
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFAD1457),
                              Color(0xFFD81B60)
                            ],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رحلة نمو الجنين',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 6),
                            const Text(
                              'تم حفظ تسجيلاتك الرقمية من جميع الجلسات السونار الخاصة بك هنا للرجوع الإلكتروني أي وقت.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white70),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              onPressed: _showAddDialog,
                              icon: const Icon(Icons.add_rounded,
                                  size: 18),
                              label: const Text('إضافة جلسة جديدة'),
                            ),
                          ],
                        ),
                      ),

                      // ── السجلات ───────────────────────────────────────
                      if (_records.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(children: [
                              Icon(Icons.graphic_eq_rounded,
                                  size: 64,
                                  color: AppColors.grey200),
                              const SizedBox(height: 16),
                              const Text('لا توجد متابعات بعد',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.grey600)),
                              const SizedBox(height: 8),
                              const Text(
                                  'اضغطي على "إضافة جلسة جديدة" للبدء',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.grey400)),
                            ]),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          itemCount: _records.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _UltrasoundCard(record: _records[i]),
                        ),

                      const SizedBox(height: 80),
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
        label: const Text('إضافة متابعة'),
      ),
    );
  }
}

// ── بطاقة السونار ─────────────────────────────────────────────────────────────
class _UltrasoundCard extends StatelessWidget {
  final UltrasoundRecord record;
  const _UltrasoundCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ────────────────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE4EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Color(0xFFAD1457), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.monthLabel,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Text(record.date,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey500)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.person_rounded,
                        size: 12, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Text(record.doctor,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.grey500)),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                record.sessionType,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3949AB)),
              ),
            ),
          ]),

          if (record.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_rounded,
                      size: 16, color: Color(0xFFE65100)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ملاحظات الطبيب',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100))),
                        const SizedBox(height: 4),
                        Text(record.notes,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.grey900,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}