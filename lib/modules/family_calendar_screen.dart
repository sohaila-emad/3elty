import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../data/app_repository.dart';
import '../data/models/calendar_event.dart';
import '../services/remote_auth_service.dart';

class FamilyCalendarScreen extends StatefulWidget {
  final List<FamilyMember> familyMembers;

  const FamilyCalendarScreen({super.key, required this.familyMembers});

  @override
  State<FamilyCalendarScreen> createState() => _FamilyCalendarScreenState();
}

class _FamilyCalendarScreenState extends State<FamilyCalendarScreen> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService.instance;

  late DateTime _weekStart;
  late DateTime _selectedDay;
  List<CalendarEvent> _events = [];
  List<FamilyMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _startOfWeek(now);
    _selectedDay = _dateOnly(now);
    _members = widget.familyMembers;
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    try {
      setState(() => _loading = true);
      final familyId = await _authService.familyId;
      if (familyId == null) throw Exception('No active family');

      if (_members.isEmpty) {
        final records = await _repo.getMembersForFamily(familyId);
        _members = records.map(FamilyMember.fromRecord).toList();
      }

      final rows = await _repo.getCalendarEventsForFamily(familyId);
      final events = rows.map((row) => CalendarEvent.fromMap(row)).toList();
      events.sort((a, b) => _eventDateTime(a).compareTo(_eventDateTime(b)));

      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load family calendar: $e');
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  DateTime get _weekEndExclusive => _weekStart.add(const Duration(days: 7));

  List<DateTime> get _weekDays => List.generate(
        7,
        (index) => _weekStart.add(Duration(days: index)),
      );

  DateTime _eventDateTime(CalendarEvent event) {
    final time = event.eventTime;
    return DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
      time?.hour ?? event.eventDate.hour,
      time?.minute ?? event.eventDate.minute,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isEventInsideVisibleWeek(CalendarEvent event) {
    final dateTime = _eventDateTime(event);
    return !dateTime.isBefore(_weekStart) && dateTime.isBefore(_weekEndExclusive);
  }

  int? _safeDayIndex(CalendarEvent event) {
    if (!_isEventInsideVisibleWeek(event)) return null;
    final eventDay = _dateOnly(_eventDateTime(event));
    final dayIndex = eventDay.difference(_weekStart).inDays;
    if (dayIndex < 0 || dayIndex > 6) return null;
    return dayIndex;
  }

  int _safeHour(CalendarEvent event) {
    final hour = event.eventTime?.hour ?? _eventDateTime(event).hour;
    if (hour < 0) return 0;
    if (hour > 23) return 23;
    return hour;
  }

  int _safeMinute(CalendarEvent event) {
    final minute = event.eventTime?.minute ?? _eventDateTime(event).minute;
    if (minute < 0) return 0;
    if (minute > 59) return 59;
    return minute;
  }

  List<CalendarEvent> get _eventsForVisibleWeek {
    final visible = _events.where((event) => _safeDayIndex(event) != null).toList();
    visible.sort((a, b) => _eventDateTime(a).compareTo(_eventDateTime(b)));
    return visible;
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final selected = _dateOnly(day);
    final events = _eventsForVisibleWeek.where((event) {
      final dayIndex = _safeDayIndex(event);
      if (dayIndex == null || dayIndex < 0 || dayIndex > 6) return false;
      return _sameDay(_eventDateTime(event), selected);
    }).toList();

    events.sort((a, b) => _eventDateTime(a).compareTo(_eventDateTime(b)));
    return events;
  }

  void _goToPreviousWeek() {
    final nextWeekStart = _weekStart.subtract(const Duration(days: 7));
    setState(() {
      _weekStart = nextWeekStart;
      _selectedDay = nextWeekStart;
    });
  }

  void _goToNextWeek() {
    final nextWeekStart = _weekStart.add(const Duration(days: 7));
    setState(() {
      _weekStart = nextWeekStart;
      _selectedDay = nextWeekStart;
    });
  }

  void _goToCurrentWeek() {
    final now = DateTime.now();
    setState(() {
      _weekStart = _startOfWeek(now);
      _selectedDay = _dateOnly(now);
    });
  }

  bool _isToday(DateTime day) => _sameDay(day, DateTime.now());

  bool _isSelected(DateTime day) => _sameDay(day, _selectedDay);

  String _weekRangeLabel() {
    final sameMonth = _weekStart.month == _weekEnd.month && _weekStart.year == _weekEnd.year;
    if (sameMonth) {
      return '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('d, yyyy').format(_weekEnd)}';
    }
    return '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d, yyyy').format(_weekEnd)}';
  }

  Color _colorForProfile(String? profileType) {
    switch (profileType) {
      case 'child':
        return const Color(0xFF1565C0);
      case 'elderly':
        return const Color(0xFF6A1B9A);
      case 'pregnant':
        return const Color(0xFFAD1457);
      case 'chronic':
        return const Color(0xFFBF360C);
      case 'adult':
        return AppColors.teal;
      default:
        return AppColors.teal;
    }
  }

  Color _softColorForProfile(String? profileType) {
    switch (profileType) {
      case 'child':
        return const Color(0xFFE3F2FD);
      case 'elderly':
        return const Color(0xFFF3E5F5);
      case 'pregnant':
        return const Color(0xFFFCE4EC);
      case 'chronic':
        return const Color(0xFFFBE9E7);
      case 'adult':
        return AppColors.tealLight;
      default:
        return AppColors.tealLight;
    }
  }

  String _timeLabel(CalendarEvent event) {
    final date = event.eventDate;
    final time = event.eventTime;
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? date.hour,
      time?.minute ?? date.minute,
    );
    return DateFormat('h:mm a').format(dateTime);
  }

  String _profileLabel(String? profileType) {
    switch (profileType) {
      case 'child':
        return 'Child';
      case 'elderly':
        return 'Elderly';
      case 'pregnant':
        return 'Pregnant';
      case 'chronic':
        return 'Chronic';
      case 'adult':
        return 'Adult';
      default:
        return 'Family';
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text(
          'Family Calendar / تقويم العائلة',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _goToCurrentWeek,
            child: const Text(
              'Today',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadCalendarEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                _buildWeekHeader(),
                _buildDaySelector(),
                Expanded(child: _buildSelectedDayEvents()),
              ],
            ),
    );
  }

  Widget _buildWeekHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Row(
        children: [
          _navButton(Icons.chevron_left_rounded, _goToPreviousWeek),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Weekly Family Calendar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _weekRangeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _navButton(Icons.chevron_right_rounded, _goToNextWeek),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            const SizedBox(width: 10),
            ..._weekDays.map((day) => _dayChip(day)),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  Widget _dayChip(DateTime day) {
    final selected = _isSelected(day);
    final today = _isToday(day);
    final eventsCount = _eventsForDay(day).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected
            ? AppColors.teal
            : today
                ? AppColors.tealLight
                : AppColors.grey50,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _selectedDay = _dateOnly(day)),
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? AppColors.teal
                    : today
                        ? AppColors.teal
                        : AppColors.grey200,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEE').format(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : today
                            ? AppColors.teal
                            : AppColors.grey600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : AppColors.grey900,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : eventsCount > 0
                            ? AppColors.tealLight
                            : AppColors.grey100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$eventsCount',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? Colors.white
                          : eventsCount > 0
                              ? AppColors.teal
                              : AppColors.grey500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final selectedEvents = _eventsForDay(_selectedDay);

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _loadCalendarEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _selectedDayHeader(selectedEvents.length),
          const SizedBox(height: 12),
          if (selectedEvents.isEmpty)
            _emptyDayState()
          else
            ...selectedEvents.map((event) => _eventTile(event)),
        ],
      ),
    );
  }

  Widget _selectedDayHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE').format(_selectedDay),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.grey900),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMM d, yyyy').format(_selectedDay),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
          ),
          child: Text(
            '$count ${count == 1 ? 'event' : 'events'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.teal),
          ),
        ),
      ],
    );
  }

  Widget _eventTile(CalendarEvent event) {
    final color = _colorForProfile(event.memberProfileType);
    final softColor = _softColorForProfile(event.memberProfileType);
    final hour = _safeHour(event);
    final minute = _safeMinute(event);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showEventDetails(event),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: softColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('h:mm').format(DateTime(2024, 1, 1, hour, minute)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('a').format(DateTime(2024, 1, 1, hour, minute)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.78)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(10)),
                            child: Icon(event.eventType.icon, color: color, size: 17),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.eventType.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.18, fontWeight: FontWeight.w900, color: AppColors.grey900),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _miniInfoChip(Icons.person_rounded, event.memberName, color, softColor),
                          _miniInfoChip(Icons.category_rounded, _profileLabel(event.memberProfileType), color, softColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfoChip(IconData icon, String text, Color color, Color softColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: softColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDayState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
            child: const Icon(Icons.event_busy_rounded, color: AppColors.teal, size: 38),
          ),
          const SizedBox(height: 16),
          const Text(
            'No events for this day',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.grey900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scheduled items appear here only when “Show on Family Calendar” is enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(CalendarEvent event) {
    final color = _colorForProfile(event.memberProfileType);
    final softColor = _softColorForProfile(event.memberProfileType);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(14)),
                      child: Icon(event.eventType.icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.grey900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            event.eventType.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: color, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow(Icons.person_rounded, 'Member', event.memberName),
                _detailRow(Icons.category_rounded, 'Profile', _profileLabel(event.memberProfileType)),
                _detailRow(Icons.calendar_today_rounded, 'Date', DateFormat('EEEE, MMM d, yyyy').format(event.eventDate)),
                _detailRow(Icons.access_time_rounded, 'Time', _timeLabel(event)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey600),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.grey600, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.grey900, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
