import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
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
  
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<CalendarEvent>> _events = {};
  bool _loading = true;
  String _filterMemberId = 'all';
  String _filterEventType = 'all';

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    try {
      setState(() => _loading = true);
      
      final familyId = await _authService.familyId;
      if (familyId == null) throw Exception('No active family');

      // Load events for entire month (with buffer for previous/next month)
      final startDate = DateTime(_focusedDay.year, _focusedDay.month, 1)
          .subtract(const Duration(days: 7));
      final endDate = DateTime(_focusedDay.year, _focusedDay.month + 1, 1)
          .add(const Duration(days: 7));

      final eventRows = await _repo.getCalendarEventsForFamily(
        familyId,
        startDate: startDate,
        endDate: endDate,
      );

      // Parse and organize events
      final Map<DateTime, List<CalendarEvent>> events = {};
      
      for (final row in eventRows) {
        final eventDate = DateTime.parse(row['event_date'] as String);
        final dateKey = DateTime(eventDate.year, eventDate.month, eventDate.day);
        
        final memberId = row['member_id'] as String;
        final memberName = widget.familyMembers
            .firstWhere((m) => m.id == memberId, orElse: () => FamilyMember(
              name: 'Unknown',
              age: 0,
              phone: '',
              profileType: ProfileType.adult,
            ))
            .name;

        final event = CalendarEvent.fromMap(row, memberName);

        events.putIfAbsent(dateKey, () => []).add(event);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Failed to load calendar: $e');
      }
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

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    var events = _events[dayKey] ?? [];

    // Apply filters
    if (_filterMemberId != 'all') {
      events = events.where((e) => e.memberId == _filterMemberId).toList();
    }
    if (_filterEventType != 'all') {
      final eventType = EventType.values[int.parse(_filterEventType)];
      events = events.where((e) => e.eventType == eventType).toList();
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Family Health Calendar'),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Filters
                  _buildFilterSection(),
                  
                  // Calendar
                  Card(
                    margin: const EdgeInsets.all(12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: TableCalendar<CalendarEvent>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        _loadCalendarEvents();
                      },
                      eventLoader: _getEventsForDay,
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppColors.tealLight,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Selected day's events
                  _buildSelectedDayEvents(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadCalendarEvents,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by:',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              // Member filter
              _buildFilterChip(
                label: 'Member',
                value: _filterMemberId,
                options: [
                  ('all', 'All Members'),
                  ...widget.familyMembers.map((m) => (m.id ?? '', m.name)),
                ],
                onChanged: (value) =>
                    setState(() => _filterMemberId = value),
              ),

              // Event type filter
              _buildFilterChip(
                label: 'Event Type',
                value: _filterEventType,
                options: const [
                  ('all', 'All Events'),
                  ('0', 'Appointments'),
                  ('1', 'Vaccinations'),
                  ('2', 'Prenatal Tests'),
                ],
                onChanged: (value) =>
                    setState(() => _filterEventType = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButton<String>(
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? value),
      items: options
          .map(
            (opt) => DropdownMenuItem(
              value: opt.$1,
              child: Text(opt.$2),
            ),
          )
          .toList(),
      underline: Container(
        height: 2,
        color: AppColors.teal,
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final events = _getEventsForDay(_selectedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events on ${DateFormat('MMMM d, y').format(_selectedDay)}',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No events scheduled',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
          else
            ...events.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final timeStr = event.eventTime != null
        ? '${event.eventTime!.hour.toString().padLeft(2, '0')}:${event.eventTime!.minute.toString().padLeft(2, '0')}'
        : 'All Day';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: event.eventType.color, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: event.eventType.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    event.eventType.icon,
                    color: event.eventType.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.memberName,
                        style: TextStyle(
                          color: AppColors.grey600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: AppColors.grey500,
                    fontSize: 12,
                  ),
                ),
                Text(
                  event.eventType.label,
                  style: TextStyle(
                    color: event.eventType.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (event.eventData != null && event.eventData!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildEventDetails(event),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails(CalendarEvent event) {
    final data = event.eventData!;
    
    switch (event.eventType) {
      case EventType.appointment:
        return Text(
          '${data['location'] != null ? '📍 ${data['location']}\n' : ''}${data['doctor'] != null ? '👨‍⚕️ Dr. ${data['doctor']}' : ''}',
          style: TextStyle(color: AppColors.grey600, fontSize: 11),
        );
      case EventType.vaccination:
        return Text(
          'Clinic: ${data['clinic_name'] ?? 'Not recorded'}\nStatus: ${data['is_received'] == 1 ? 'Received ✓' : 'Due'}',
          style: TextStyle(color: AppColors.grey600, fontSize: 11),
        );
      case EventType.prenatalTest:
        return Text(
          'Trimester: T${data['trimester']}\nStatus: ${data['is_completed'] == 1 ? 'Completed ✓' : 'Pending'}',
          style: TextStyle(color: AppColors.grey600, fontSize: 11),
        );
    }
  }
}
