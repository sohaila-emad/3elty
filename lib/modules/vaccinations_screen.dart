import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

class VaccinationsScreen extends StatefulWidget {
  final FamilyMember member;
  const VaccinationsScreen({super.key, required this.member});

  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();
  List<dynamic> _vaccinations = [];
  bool _loading = true;

  // Egypt MOH Vaccination Schedule — ageMonths = due age milestone
  static const List<Map<String, dynamic>> _fullSchedule = [
    {'vaccine': 'BCG',                     'ageLabel': 'عند الولادة',  'ageMonths': 0},
    {'vaccine': 'Hepatitis B (Birth)',      'ageLabel': 'عند الولادة',  'ageMonths': 0},
    {'vaccine': 'DPT 1',                   'ageLabel': 'شهران',         'ageMonths': 2},
    {'vaccine': 'Polio 1',                 'ageLabel': 'شهران',         'ageMonths': 2},
    {'vaccine': 'Hepatitis B 1',           'ageLabel': 'شهران',         'ageMonths': 2},
    {'vaccine': 'DPT 2',                   'ageLabel': '٤ أشهر',        'ageMonths': 4},
    {'vaccine': 'Polio 2',                 'ageLabel': '٤ أشهر',        'ageMonths': 4},
    {'vaccine': 'Hepatitis B 2',           'ageLabel': '٤ أشهر',        'ageMonths': 4},
    {'vaccine': 'DPT 3',                   'ageLabel': '٦ أشهر',        'ageMonths': 6},
    {'vaccine': 'Polio 3',                 'ageLabel': '٦ أشهر',        'ageMonths': 6},
    {'vaccine': 'Hepatitis B 3',           'ageLabel': '٦ أشهر',        'ageMonths': 6},
    {'vaccine': 'MMR',                     'ageLabel': '١٢ شهراً',      'ageMonths': 12},
    {'vaccine': 'DPT Booster 1',           'ageLabel': '١٨ شهراً',      'ageMonths': 18},
    {'vaccine': 'Polio Booster',           'ageLabel': '١٨ شهراً',      'ageMonths': 18},
    {'vaccine': 'MMR 2 / Measles Booster', 'ageLabel': '٢٤ شهراً',      'ageMonths': 24},
    {'vaccine': 'DPT Booster 2',           'ageLabel': '٦ سنوات',       'ageMonths': 72},
    {'vaccine': 'Td (Tetanus-Diphtheria)', 'ageLabel': '١٢ سنة',        'ageMonths': 144},
  ];

  // Vaccines due up to child's current age (in years → converted to months)
  List<Map<String, dynamic>> get _dueSchedule {
    final ageMonths = widget.member.age * 12;
    return _fullSchedule
        .where((v) => (v['ageMonths'] as int) <= ageMonths)
        .toList();
  }

  // Vaccines not yet due but coming within 6 months
  List<Map<String, dynamic>> get _upcomingSchedule {
    final ageMonths = widget.member.age * 12;
    return _fullSchedule
        .where((v) {
          final va = v['ageMonths'] as int;
          return va > ageMonths && va <= ageMonths + 6;
        })
        .toList();
  }

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

  Future<void> _markVaccine(String vaccineName) async {
    if (widget.member.id == null) return;
    try {
      final familyId = await _authService.familyId;
      if (!mounted) return;
      if (familyId == null) { _showError('لم يتم العثور على العائلة'); return; }
      await _repo.insertVaccination(VaccinationRecord(
        familyId: familyId,
        memberId: widget.member.id!,
        vaccineName: vaccineName,
        isReceived: true,
        receivedAt: DateTime.now().toIso8601String().split('T').first,
      ));
      if (!mounted) return;
      _showSuccess('تم تسجيل "$vaccineName" ✓');
      await _loadVaccinations();
    } catch (e) {
      if (!mounted) return;
      _showError('فشل التسجيل: $e');
    }
  }

  bool _isLogged(String v) => _vaccinations.any((r) => r.vaccineName.contains(v));

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white))));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.green, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(msg, style: const TextStyle(color: Colors.white))));

  @override
  Widget build(BuildContext context) {
    final t = widget.member.profileType;
    final due = _dueSchedule;
    final upcoming = _upcomingSchedule;
    final logged = due.where((v) => _isLogged(v['vaccine'] as String)).length;

    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(title: const Text('التطعيمات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : CustomScrollView(
              slivers: [
                // Member header
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(width: 48, height: 48,
                          decoration: BoxDecoration(color: t.bgColor, borderRadius: BorderRadius.circular(12)),
                          child: Icon(t.icon, color: t.color, size: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.member.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.grey900)),
                        Text('${widget.member.age} سنة', style: TextStyle(fontSize: 13, color: t.color, fontWeight: FontWeight.w500)),
                      ])),
                      // Progress badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('$logged / ${due.length}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(height: 1)),

                // ── Due vaccines section ──
                if (due.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(32),
                        child: Center(child: Text('لا توجد تطعيمات مستحقة لهذا العمر حتى الآن',
                            style: TextStyle(fontSize: 15, color: AppColors.grey500), textAlign: TextAlign.center))),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('التطعيمات المستحقة حتى الآن',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.grey600))),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: due.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final v = due[i]['vaccine'] as String;
                        final logged = _isLogged(v);
                        return _VaccineCard(
                          vaccine: v, ageLabel: due[i]['ageLabel'] as String,
                          isLogged: logged, isPast: true,
                          onMark: logged ? null : () => _markVaccine(v),
                        );
                      },
                    ),
                  ),
                ],

                // ── Upcoming vaccines section ──
                if (upcoming.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(children: [
                          const Icon(Icons.schedule_rounded, size: 16, color: AppColors.teal),
                          const SizedBox(width: 6),
                          const Text('قادم خلال ٦ أشهر',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.teal)),
                        ])),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: upcoming.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _VaccineCard(
                        vaccine: upcoming[i]['vaccine'] as String,
                        ageLabel: upcoming[i]['ageLabel'] as String,
                        isLogged: false, isPast: false, onMark: null,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}

// ── Vaccine card ──────────────────────────────────────────────────────────────
class _VaccineCard extends StatelessWidget {
  final String vaccine;
  final String ageLabel;
  final bool isLogged;
  final bool isPast;
  final VoidCallback? onMark;

  const _VaccineCard({
    required this.vaccine, required this.ageLabel,
    required this.isLogged, required this.isPast, this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isLogged
          ? AppColors.green.withValues(alpha: 0.05)
          : isPast ? Colors.white : AppColors.grey50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: isLogged
                    ? AppColors.green.withValues(alpha: 0.12)
                    : isPast ? AppColors.grey100 : AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
              isLogged ? Icons.check_circle_rounded
                  : isPast ? Icons.radio_button_unchecked_rounded
                  : Icons.schedule_rounded,
              color: isLogged ? AppColors.green
                  : isPast ? AppColors.grey400 : AppColors.teal,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vaccine, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: isLogged ? AppColors.green : AppColors.grey900)),
            const SizedBox(height: 2),
            Text(ageLabel, style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
          ])),
          if (isLogged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
              child: const Text('تم ✓', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
            )
          else if (isPast && onMark != null)
            TextButton(
              onPressed: onMark,
              style: TextButton.styleFrom(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              child: const Text('سجّل', style: TextStyle(fontSize: 12, color: AppColors.teal, fontWeight: FontWeight.w600)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(20)),
              child: const Text('قادم', style: TextStyle(fontSize: 12, color: AppColors.grey500, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}
