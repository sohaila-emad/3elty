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
import 'widgets/premium_ui.dart';
import 'screens/profile_intro_animation_screen.dart';

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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '3elty Family',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF12312D),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
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
          FutureBuilder<String?>(
            future: _authService.userRole,
            builder: (ctx, snapshot) {
              if (snapshot.data == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.people_outline_rounded),
                  tooltip: 'Manage Family Members',
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/admin_member_management')
                      .then((_) => _loadMembers()),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign in again to access your family data.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await RemoteAuthService.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: AppColors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showSOSConfirmation,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Icon(Icons.sos_rounded, color: AppColors.red, size: 19),
                    SizedBox(width: 5),
                    Text('SOS',
                        style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PremiumScaffoldBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _dashboardBody(),
        ),
      ),
    );
  }

  Widget _dashboardBody() => RefreshIndicator(
        onRefresh: _refreshFromFirestore,
        color: AppColors.teal,
        backgroundColor: Colors.white,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
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
            const SizedBox(height: 14),
            const PremiumSectionTitle(
              icon: Icons.family_restroom_rounded,
              title: 'Family Members / أفراد العائلة',
              subtitle: 'Open a profile to manage care modules',
              color: AppColors.teal,
            ),
            const SizedBox(height: 12),
            if (_members.isEmpty)
              _emptyStateContent()
            else
              ..._members.map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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


  Widget _emptyStateContent() => GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const GradientIconBox(
            icon: Icons.group_add_rounded,
            color: AppColors.teal,
            size: 72,
            iconSize: 36,
            radius: 24,
          ),
          const SizedBox(height: 20),
          const Text('No family members yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF12312D))),
          const SizedBox(height: 8),
          Text(
              'Ask your admin to add members, then tap refresh to sync.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF12312D).withOpacity(0.62),
                  height: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _refreshing ? null : _refreshFromFirestore,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh now'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.teal),
              foregroundColor: AppColors.teal,
              backgroundColor: Colors.white.withOpacity(0.64),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    if (count == 0) return 'No events this week';
    if (count == 1) return '1 event this week';
    return '$count events this week';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      radius: 28,
      padding: EdgeInsets.zero,
      tint: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.teal.withOpacity(0.92),
              const Color(0xFF2BBEA9).withOpacity(0.82),
              const Color(0xFFF8FFFC).withOpacity(0.72),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.42)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withOpacity(0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 29),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Calendar / تقويم العائلة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.18,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'View your family schedule',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.teal, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PremiumPill(
                  icon: Icons.date_range_rounded,
                  label: weekRange,
                  color: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.18),
                ),
                PremiumPill(
                  icon: Icons.event_available_rounded,
                  label: loading ? 'Loading...' : _eventCountLabel(),
                  color: AppColors.teal,
                  backgroundColor: Colors.white.withOpacity(0.92),
                ),
              ],
            ),
          ],
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
    return GlassCard(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 22,
      padding: const EdgeInsets.all(13),
      tint: Colors.white,
      border: Border.all(color: t.color.withOpacity(0.12)),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.bgColor, Colors.white.withOpacity(0.86)],
            ),
            border: Border.all(color: t.color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: t.color.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF12312D),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  PremiumPill(label: t.label, color: t.color, backgroundColor: t.bgColor),
                  PremiumPill(icon: Icons.cake_rounded, label: member.formattedAge, color: AppColors.grey600, backgroundColor: Colors.white.withOpacity(0.70)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: t.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.chevron_right_rounded, color: t.color),
        ),
      ]),
    );
  }
}
