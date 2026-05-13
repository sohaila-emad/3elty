import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'services/remote_auth_service.dart';
import 'services/firestore_service.dart';
import 'main.dart';
import 'data/app_repository.dart';
import 'utils/error_handler.dart';
import 'screens/first_time_setup_screen.dart';
import 'modules/family_calendar_screen.dart';
import 'data/models/calendar_event.dart';

class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key});

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  final _repo             = AppRepository.instance;
  final _authService      = RemoteAuthService();
  final _firestoreService = FirestoreService();   // ← for refresh

  List<FamilyMember> _members   = [];
  List<CalendarEvent> _calendarEvents = [];
  bool _calendarLoading = false;
  bool _loading                  = true;
  bool _refreshing               = false;         // ← separate flag for refresh

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ── Load from local SQLite (fast, used on startup) ──────────────────────────
  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final familyId = await _authService.familyId;
      if (familyId == null) {
        _showError('Family not found. Please sign in again.');
        return;
      }
      final records = await _repo.getMembersForFamily(familyId);
      if (!mounted) return;
      setState(() {
        _members = records.map(FamilyMember.fromRecord).toList();
        _loading = false;
      });
      await _loadCalendarPreview(familyId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Could not load family members: $e');
    }
  }


  Future<void> _loadCalendarPreview(String familyId) async {
    try {
      setState(() => _calendarLoading = true);
      final rows = await _repo.getCalendarEventsForFamily(familyId);
      final events = rows.map((row) => CalendarEvent.fromMap(row)).toList();
      final today = DateTime.now();
      final startToday = DateTime(today.year, today.month, today.day);
      events.removeWhere((event) => event.eventDate.isBefore(startToday));
      events.sort((a, b) => _calendarEventDateTime(a).compareTo(_calendarEventDateTime(b)));
      if (!mounted) return;
      setState(() {
        _calendarEvents = events.take(5).toList();
        _calendarLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _calendarLoading = false);
    }
  }


  DateTime _calendarEventDateTime(CalendarEvent event) {
    final time = event.eventTime;
    return DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
      time?.hour ?? event.eventDate.hour,
      time?.minute ?? event.eventDate.minute,
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
  }

  String _currentWeekRangeLabel() {
    final start = _startOfWeek(DateTime.now());
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month && start.year == end.year) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
  }

  // ── REFRESH: pull from Firestore → update SQLite → reload UI ───────────────
  Future<void> _refreshFromFirestore() async {
    setState(() => _refreshing = true);
    try {
      // Re-sync Firestore → local SQLite
      await _firestoreService.syncFamilyData();
      // Then reload from SQLite
      await _loadMembers();
      if (mounted) _showSuccess('Family data refreshed');
    } catch (e) {
      if (mounted) _showError('Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // ── Delete member ───────────────────────────────────────────────────────────
  Future<void> _confirmDeleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove ${member.name}?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will permanently delete all their health data — medications, vitals, appointments and documents.',
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || member.id == null) return;

    try {
      await _repo.deleteMember(member.id!);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m.id == member.id));
      _showSuccess('${member.name} removed');
    } catch (e) {
      _showError('Could not delete member: $e');
    }
  }

  // ── SOS ─────────────────────────────────────────────────────────────────────
  void _showSOSConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: AppColors.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.sos_rounded, color: AppColors.red, size: 32),
        ),
        title: const Text('Send emergency alert?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will broadcast your GPS location to ALL family members.\n\nOnly use in a real emergency.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.grey600, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, kMinTouch),
                  side: const BorderSide(color: AppColors.grey200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('No, cancel',
                    style: TextStyle(
                        color: AppColors.grey900, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  minimumSize: const Size(double.infinity, kMinTouch),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.red,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: const Row(children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              'Emergency alert sent to all family members',
                              style: TextStyle(color: Colors.white))),
                    ]),
                  ));
                },
                child: const Text('Yes, send SOS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ])
        ],
      ),
    );
  }

  void _showSuccess(String msg) => ErrorHandler.showSuccess(context, msg);
  void _showError(String msg)   => ErrorHandler.showError(context, msg);

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('My Family'),
        actions: [
          // ── REFRESH BUTTON ─────────────────────────────────────────────────
          _refreshing
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.teal,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh from cloud',
                  onPressed: _refreshFromFirestore,
                ),

          // Admin: Manage Family button
          FutureBuilder<String?>(
            future: _authService.userRole,
            builder: (ctx, snapshot) {
              if (snapshot.data == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.people_outline_rounded),
                  tooltip: 'Manage Family Members',
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/admin_member_management')
                      .then((_) => _loadMembers()), // reload after returning
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Sign out
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                      'You will need to sign in again to access your family data.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await RemoteAuthService.instance.signOut(); // ← clears secure storage tokens
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),

          // SOS button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: AppColors.redLight,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showSOSConfirmation,
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.sos_rounded, color: AppColors.red, size: 20),
                    SizedBox(width: 6),
                    Text('SOS',
                        style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : _dashboardBody(),
    );
  }


  Widget _dashboardBody() => RefreshIndicator(
        onRefresh: _refreshFromFirestore,
        color: AppColors.teal,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _FamilyCalendarPreviewCard(
              loading: _calendarLoading,
              weekRange: _currentWeekRangeLabel(),
              events: _calendarEvents,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyCalendarScreen(familyMembers: _members),
                ),
              ).then((_) async {
                final familyId = await _authService.familyId;
                if (familyId != null) _loadCalendarPreview(familyId);
              }),
            ),
            const SizedBox(height: 16),
            if (_members.isEmpty)
              _emptyStateContent()
            else ...[
              const Padding(
                padding: EdgeInsets.only(left: 4, right: 4, bottom: 10),
                child: Text(
                  'Family Members / أفراد العائلة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.grey900,
                  ),
                ),
              ),
              ..._members.map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MemberCard(
                      member: member,
                      onTap: () async {
                        final phone = member.phone ?? '';
                        print('DEBUG phone: "$phone"');
                        print('DEBUG member.name: "${member.name}"');
                        if (phone.isNotEmpty) {
                          final hasPin = await _authService.hasMemberSetPin(phone);
                          print('DEBUG hasPin: $hasPin');
                          if (!hasPin) {
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FirstTimeSetupScreen(),
                                ),
                              );
                            }
                            return;
                          }
                        }
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemberProfileScreen(member: member),
                            ),
                          );
                        }
                      },
                      onLongPress: () => _confirmDeleteMember(member),
                    ),
                  )),
            ],
          ],
        ),
      );

  Widget _emptyStateContent() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: AppColors.tealLight, shape: BoxShape.circle),
            child: const Icon(Icons.group_add_rounded,
                size: 48, color: AppColors.teal),
          ),
          const SizedBox(height: 24),
          const Text('No family members yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Ask your admin to add members,\nthen tap refresh to sync.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: AppColors.grey600,
                  height: 1.5)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _refreshing ? null : _refreshFromFirestore,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh now'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.teal),
              foregroundColor: AppColors.teal,
            ),
          ),
        ]),
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: AppColors.tealLight, shape: BoxShape.circle),
              child: const Icon(Icons.group_add_rounded,
                  size: 48, color: AppColors.teal),
            ),
            const SizedBox(height: 24),
            const Text('No family members yet',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'Ask your admin to add members,\nthen tap refresh to sync.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.grey600,
                    height: 1.5)),
            const SizedBox(height: 24),
            // ── Refresh hint when empty ───────────────────────────────────
            OutlinedButton.icon(
              onPressed: _refreshing ? null : _refreshFromFirestore,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh now'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.teal),
                foregroundColor: AppColors.teal,
              ),
            ),
          ]),
        ),
      );

  Widget _memberList() => RefreshIndicator(
        // ── Pull-to-refresh also works ─────────────────────────────────────
        onRefresh: _refreshFromFirestore,
        color: AppColors.teal,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _members.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final member = _members[i];
            return _MemberCard(
              member: member,
              onTap: () async {
                final phone = member.phone ?? '';
                print('DEBUG phone: "$phone"');
                print('DEBUG member.name: "${member.name}"');
                if (phone.isNotEmpty) {
                  final hasPin = await _authService.hasMemberSetPin(phone);
                  print('DEBUG hasPin: $hasPin');
                  if (!hasPin) {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FirstTimeSetupScreen(),
                        ),
                      );
                    }
                    return;
                  }
                }
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberProfileScreen(member: member),
                    ),
                  );
                }
              },
              onLongPress: () => _confirmDeleteMember(member),
            );
          },
        ),
      );
}


class _FamilyCalendarPreviewCard extends StatelessWidget {
  final bool loading;
  final String weekRange;
  final List<CalendarEvent> events;
  final VoidCallback onTap;

  const _FamilyCalendarPreviewCard({
    required this.loading,
    required this.weekRange,
    required this.events,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: AppColors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Family Calendar / تقويم العائلة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weekRange,
                          style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.grey600),
                ],
              ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator(color: AppColors.teal)),
                )
              else if (events.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.grey200),
                  ),
                  child: const Text(
                    'No visible family events. Enable “Show on Family Calendar” from add/edit forms.',
                    style: TextStyle(color: AppColors.grey600, height: 1.4),
                  ),
                )
              else
                Column(
                  children: events.map((event) => _PreviewEventChip(event: event)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewEventChip extends StatelessWidget {
  final CalendarEvent event;

  const _PreviewEventChip({required this.event});

  Color _profileColor(String? profileType) {
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

  Color _profileSoftColor(String? profileType) {
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

  String _eventDateTimeLabel() {
    final time = event.eventTime;
    final dateTime = DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
      time?.hour ?? event.eventDate.hour,
      time?.minute ?? event.eventDate.minute,
    );
    return '${DateFormat('MMM d').format(dateTime)} • ${DateFormat('h:mm a').format(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _profileColor(event.memberProfileType);
    final softColor = _profileSoftColor(event.memberProfileType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
            child: Icon(event.eventType.icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.grey900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_eventDateTimeLabel()} • ${event.memberName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.grey600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              event.eventType.arabicLabel,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Member card ───────────────────────────────────────────────────────────────
class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final t = member.profileType;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: t.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(t.icon, color: t.color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: t.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      member.formattedAge,
                      style: const TextStyle(fontSize: 13, color: AppColors.grey600),
                    ),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey600),
          ]),
        ),
      ),
    );
  }
}
