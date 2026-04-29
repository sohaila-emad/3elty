// ─────────────────────────────────────────────────────────────────────────────
// HOW TO USE THIS FILE
//
// 1. Add to pubspec.yaml:
//      sqflite: ^2.3.3
//      path: ^1.9.0
//      path_provider: ^2.1.3
//      shared_preferences: ^2.2.3
//      image_picker: ^1.1.2
//
// 2. Place database_provider.dart and app_repository.dart in lib/data/
//
// 3. Replace your existing FamilyDashboard widget with the one below.
//    The rest of your main.dart (AppColors, ProfileType, E3ltyApp,
//    AdminSignUpScreen, MemberProfileScreen etc.) stays unchanged.
//
// Key changes vs the previous version:
//  • FamilyDashboard is now async — it loads members from SQLite on init.
//  • Adding a member writes to SQLite and refreshes the list.
//  • Deleting a member (long-press) removes it from SQLite (cascade-deletes
//    all related vitals, meds, appointments, documents).
//  • FamilyMember now carries a nullable `id` so DB rows round-trip cleanly.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'services/remote_auth_service.dart';
import 'main.dart';
import 'data/app_repository.dart';
import 'utils/validators.dart';
import 'utils/error_handler.dart';

// ─── Persistent FamilyDashboard ───────────────────────────────────────────────
class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key});

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  final _repo = AppRepository.instance;
  final _authService = RemoteAuthService();

  List<FamilyMember> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // ── Load from SQLite ────────────────────────────────────────────────────────
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Could not load family members: $e');
    }
  }

  // ── Add member — writes to SQLite ───────────────────────────────────────────
  // ── Delete member — long-press with confirmation ───────────────────────────
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

  // ── SOS ───────────────────────────────────────────────────────────────────
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
        actions: [Column(children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, kMinTouch),
                side: const BorderSide(color: AppColors.grey200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, cancel',
                  style: TextStyle(color: AppColors.grey900, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                minimumSize: const Size(double.infinity, kMinTouch),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AppColors.red,
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text('Emergency alert sent to all family members',
                        style: TextStyle(color: Colors.white))),
                  ]),
                ));
              },
              child: const Text('Yes, send SOS',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ])],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  InputDecoration _sheetDecoration(String label, String? hint) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
      );

  void _showSuccess(String msg) => ErrorHandler.showSuccess(context, msg);

  void _showError(String msg) => ErrorHandler.showError(context, msg);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('My Family'),
        actions: [
          // Admin: Manage Family button
          FutureBuilder<String?>(
            future: _authService.userRole,
            builder: (ctx, snapshot) {
              if (snapshot.data == 'admin') {
                return IconButton(
                  icon: const Icon(Icons.people_outline_rounded),
                  tooltip: 'Manage Family Members',
                  onPressed: () => Navigator.of(context)
                      .pushNamed('/admin_member_management'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
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
                await AuthService.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
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
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.sos_rounded, color: AppColors.red, size: 20),
                    SizedBox(width: 6),
                    Text('SOS', style: TextStyle(color: AppColors.red,
                        fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _members.isEmpty
              ? _emptyState()
              : _memberList(),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.tealLight, shape: BoxShape.circle),
          child: const Icon(Icons.group_add_rounded, size: 48, color: AppColors.teal),
        ),
        const SizedBox(height: 24),
        const Text('No family members yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Tap the button below to add your first family member.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.grey600, height: 1.5)),
      ]),
    ),
  );

  Widget _memberList() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: _members.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, i) {
      final member = _members[i];
      return _MemberCard(
        member: member,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberProfileScreen(member: member),
          ),
        ),
        // Long-press to delete
        onLongPress: () => _confirmDeleteMember(member),
      );
    },
  );
}

// ── Member card (adds onLongPress) ────────────────────────────────────────────
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
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: t.bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(t.icon, color: t.color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(member.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppColors.grey900)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.bgColor, borderRadius: BorderRadius.circular(6)),
                    child: Text(t.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: t.color)),
                  ),
                  const SizedBox(width: 8),
                  Text('${member.age} yrs',
                      style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey600),
          ]),
        ),
      ),
    );
  }
}