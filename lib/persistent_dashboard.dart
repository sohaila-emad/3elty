import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'services/remote_auth_service.dart';
import 'services/firestore_service.dart';
import 'services/sos_service.dart';
import 'main.dart';
import 'data/app_repository.dart';
import 'utils/error_handler.dart';
import 'screens/first_time_setup_screen.dart';

import 'modules/family_calendar_screen.dart';
import 'data/models/calendar_event.dart';
import 'screens/profile_intro_animation_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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
      final weekStart = _startOfWeek(DateTime.now());
      final weekEndExclusive = weekStart.add(const Duration(days: 7));

      events.removeWhere((event) {
        final date = DateTime(
          event.eventDate.year,
          event.eventDate.month,
          event.eventDate.day,
        );
        return date.isBefore(weekStart) || !date.isBefore(weekEndExclusive);
      });

      events.sort((a, b) => _calendarEventDateTime(a).compareTo(_calendarEventDateTime(b)));
      if (!mounted) return;
      setState(() {
        _calendarEvents = events;
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
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.heavyImpact();

                  // Show "sending" snackbar
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: AppColors.red,
                    duration: const Duration(seconds: 30),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: const Row(children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                          child: Text('Sending SOS alert...',
                              style: TextStyle(color: Colors.white))),
                    ]),
                  ));

                  final result = await SosService.instance
                      .triggerSOS(memberName: 'Family Member');

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor:
                        result.success ? AppColors.red : AppColors.grey600,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: Row(children: [
                      Icon(
                        result.success
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                        result.success
                            ? 'Emergency alert sent to family member(s)'
                            : result.errorMessage ??
                                'SOS failed. Please try again.',
                        style: const TextStyle(color: Colors.white),
                      )),
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

      body: Column(
        children: [
          // ── SOS Alert Banner ───────────────────────────────────────────────
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: SosService.instance.activeAlertsStream(),
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              if (alerts.isEmpty) return const SizedBox.shrink();
              return Column(
                children: alerts.map((alert) {
                  final name    = alert['member_name'] as String? ?? 'A family member';
                  final lat     = alert['latitude']    as double?;
                  final lng     = alert['longitude']   as double?;
                  final alertId = alert['id']          as String? ?? '';
                  final mapsUrl = (lat != null && lng != null)
                      ? 'https://maps.google.com/?q=$lat,$lng'
                      : null;
                  return _SosAlertBanner(
                    memberName: name,
                    mapsUrl:    mapsUrl,
                    alertId:    alertId,
                  );
                }).toList(),
              );
            },
          ),
          // ── Main content ───────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.teal))
                : _dashboardBody(),
          ),
        ],
      ),
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
                          _openMemberProfileWithIntro(member);
                        }
                      },
                      onLongPress: () => _confirmDeleteMember(member),
                    ),
                  )),
            ],
          ],
        ),
      );

  void _openMemberProfileWithIntro(FamilyMember member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileIntroAnimationScreen(
          member: member,
          nextScreen: MemberProfileScreen(member: member),
        ),
      ),
    );
  }


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
                  _openMemberProfileWithIntro(member);
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

  String _eventCountLabel() {
    final count = events.length;
    if (count == 0) return 'No events this week / لا توجد مواعيد هذا الأسبوع';
    if (count == 1) return '1 event this week / موعد واحد هذا الأسبوع';
    return '$count events this week / $count مواعيد هذا الأسبوع';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE0F7F4),
                Colors.white,
              ],
            ),
            border: Border.all(color: Color(0xFFD6EFEC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Family Calendar / تقويم العائلة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.grey900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'View your family schedule',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _CalendarInfoPill(
                            icon: Icons.date_range_rounded,
                            label: weekRange,
                            foregroundColor: AppColors.grey600,
                            backgroundColor: Colors.white,
                          ),
                          _CalendarInfoPill(
                            icon: Icons.event_available_rounded,
                            label: loading ? 'Loading...' : _eventCountLabel(),
                            foregroundColor: AppColors.teal,
                            backgroundColor: AppColors.tealLight,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Color(0xFFD6EFEC)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.teal,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _CalendarInfoPill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
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


// ── SOS Alert Banner ──────────────────────────────────────────────────────────
class _SosAlertBanner extends StatefulWidget {
  final String  memberName;
  final String? mapsUrl;
  final String  alertId;

  const _SosAlertBanner({
    required this.memberName,
    required this.alertId,
    this.mapsUrl,
  });

  @override
  State<_SosAlertBanner> createState() => _SosAlertBannerState();
}

class _SosAlertBannerState extends State<_SosAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double>    _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.55).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _openMaps() async {
    if (widget.mapsUrl == null) return;
    final uri = Uri.parse(widget.mapsUrl!);
    
    // Try Google Maps app first, then fall back to browser
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open in browser
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
  

  Future<void> _resolve() async {
    await SosService.instance.resolveAlert(widget.alertId);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:        AppColors.red,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:      AppColors.red.withOpacity(0.35),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.sos_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 SOS — ${widget.memberName}',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text(
              'Emergency alert! This person needs help.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(children: [
              if (widget.mapsUrl != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:            const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: _openMaps,
                    icon:  const Icon(Icons.location_on_rounded, size: 16),
                    label: const Text('View Location',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              if (widget.mapsUrl != null) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _resolve,
                  icon:  const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Resolve',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
