import 'package:flutter/material.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../services/remote_auth_service.dart';

// ─── Admin Family Calendar ────────────────────────────────────────────────────
// Shows ALL family appointments on a monthly calendar. Admin can tap any day
// to see the appointments for that day (read-only).

class AdminFamilyCalendarScreen extends StatefulWidget {
  const AdminFamilyCalendarScreen({super.key});

  @override
  State<AdminFamilyCalendarScreen> createState() =>
      _AdminFamilyCalendarScreenState();
}

class _AdminFamilyCalendarScreenState
    extends State<AdminFamilyCalendarScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();

  // All appointments keyed by "YYYY-MM-DD"
  Map<String, List<_CalEvent>> _eventsByDay = {};
  List<FamilyMember> _members = [];
  bool _loading = true;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  // Palette for members (cycles through)
  static const _palette = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFAD1457),
    Color(0xFFBF360C),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) return;

      final memberRecords = await _repo.getMembersForFamily(familyId);
      final members =
          memberRecords.map(FamilyMember.fromRecord).toList();

      // Load appointments for every member
      final Map<String, List<_CalEvent>> byDay = {};
      for (var i = 0; i < members.length; i++) {
        final m = members[i];
        if (m.id == null) continue;
        final appts = await _repo.getAppointmentsForMember(m.id!);
        final color = _palette[i % _palette.length];
        for (final a in appts) {
          // scheduledAt is "YYYY-MM-DD"
          final key = a.scheduledAt.length >= 10
              ? a.scheduledAt.substring(0, 10)
              : a.scheduledAt;
          byDay.putIfAbsent(key, () => []).add(_CalEvent(
            memberName: m.name,
            title: a.title,
            doctor: a.doctor,
            location: a.location,
            color: color,
            memberIcon: m.profileType.icon,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _eventsByDay = byDay;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('تعذّر تحميل التقويم : $e',
            style: const TextStyle(color: Colors.white)),
      ));
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_CalEvent> _eventsFor(DateTime d) =>
      _eventsByDay[_dayKey(d)] ?? [];

  List<DateTime> _daysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(month.year, month.month, i + 1));
  }

  // First weekday offset (Saturday = 0 in Arabic week)
  int _startOffset(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    // Flutter weekday: Mon=1 … Sun=7. We want Sat=0
    return (first.weekday + 1) % 7;
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isSelected(DateTime d) =>
      _selectedDay != null &&
      d.year == _selectedDay!.year &&
      d.month == _selectedDay!.month &&
      d.day == _selectedDay!.day;

  static const _monthNames = [
    'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static const _dayLabels = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('تقويم العائلة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'اليوم',
            onPressed: () => setState(() {
              _focusedMonth =
                  DateTime(DateTime.now().year, DateTime.now().month);
              _selectedDay = DateTime(
                  DateTime.now().year, DateTime.now().month, DateTime.now().day);
            }),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                _buildCalendar(),
                const Divider(height: 1),
                Expanded(child: _buildDayPanel()),
              ],
            ),
    );
  }

  // ── Calendar grid ────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Month navigation
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grey900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                ),
              ],
            ),
          ),
          // Day labels (Sat–Fri)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _dayLabels
                  .map((l) => Expanded(
                        child: Center(
                          child: Text(l,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey500)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Day cells
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final days = _daysInMonth(_focusedMonth);
    final offset = _startOffset(_focusedMonth);
    final cells = <Widget>[];

    // Empty cells before first day
    for (var i = 0; i < offset; i++) cells.add(const SizedBox());

    for (final d in days) {
      final events = _eventsFor(d);
      final selected = _isSelected(d);
      final today = _isToday(d);
      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = d),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.teal
                  : today
                      ? AppColors.teal.withValues(alpha: 0.08)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        today || selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected
                        ? Colors.white
                        : today
                            ? AppColors.teal
                            : AppColors.grey900,
                  ),
                ),
                if (events.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: events
                          .take(3)
                          .map((e) => Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : e.color,
                                  shape: BoxShape.circle,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  // ── Day panel ────────────────────────────────────────────────────────────────

  Widget _buildDayPanel() {
    if (_selectedDay == null) {
      return const Center(
          child: Text('اختر يوماً لعرض المواعيد',
              style: TextStyle(color: AppColors.grey500)));
    }
    final events = _eventsFor(_selectedDay!);
    final label =
        '${_selectedDay!.day} ${_monthNames[_selectedDay!.month - 1]} ${_selectedDay!.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey900)),
        ),
        if (events.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available_rounded,
                      size: 56, color: AppColors.grey200),
                  const SizedBox(height: 12),
                  const Text('لا توجد مواعيد في هذا اليوم',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.grey500)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = events[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: e.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(e.memberIcon, color: e.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.memberName,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: e.color)),
                              const SizedBox(height: 2),
                              Text(e.title,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.grey900)),
                              if (e.doctor != null) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.person_outline,
                                      size: 14, color: AppColors.grey500),
                                  const SizedBox(width: 4),
                                  Text(e.doctor!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.grey600)),
                                ]),
                              ],
                              if (e.location != null) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: AppColors.grey500),
                                  const SizedBox(width: 4),
                                  Text(e.location!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.grey600)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Internal model ──────────────────────────────────────────────────────────────
class _CalEvent {
  final String memberName;
  final String title;
  final String? doctor;
  final String? location;
  final Color color;
  final IconData memberIcon;

  const _CalEvent({
    required this.memberName,
    required this.title,
    this.doctor,
    this.location,
    required this.color,
    required this.memberIcon,
  });
}
