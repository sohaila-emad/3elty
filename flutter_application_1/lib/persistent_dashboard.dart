import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';
import 'services/remote_auth_service.dart';
import 'main.dart';
import 'data/app_repository.dart';
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

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final familyId = await _authService.familyId;
      
      if (familyId == null) {
        _showError('لم يتم العثور على العائلة. يرجى تسجيل الدخول مجدداً.');
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
      _showError('تعذّر تحميل أفراد العائلة: $e');
    }
  }

  Future<void> _confirmDeleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف ${member.name}؟',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'سيتم حذف جميع بياناته الصحية نهائياً — الأدوية والعلامات الحيوية والمواعيد والوثائق.',
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppColors.grey600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || member.id == null) return;

    try {
      await _repo.deleteMember(member.id!);
      if (!mounted) return;
      setState(() => _members.removeWhere((m) => m.id == member.id));
      _showSuccess('تم حذف ${member.name}');
    } catch (e) {
      _showError('تعذّر حذف الفرد: $e');
    }
  }

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
        title: const Text('إرسال تنبيه طارئ؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        content: const Text(
          'سيتم بث موقعك الجغرافي لجميع أفراد العائلة.\n\nاستخدم هذا في حالات الطوارئ الحقيقية فقط.',
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
              child: const Text('لا، إلغاء',
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
                    Expanded(child: Text('تم إرسال تنبيه الطوارئ لجميع أفراد العائلة',
                        style: TextStyle(color: Colors.white))),
                  ]),
                ));
              },
              child: const Text('نعم، أرسل SOS',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ])],
      ),
    );
  }

  void _showSuccess(String msg) => ErrorHandler.showSuccess(context, msg);

  void _showError(String msg) => ErrorHandler.showError(context, msg);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('عيلتي'),
        actions: [
          FutureBuilder<String?>(
            future: _authService.userRole,
            builder: (ctx, snapshot) {
              if (snapshot.data == 'admin') {
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded),
                    tooltip: 'كالندر العائلة',
                    onPressed: () => Navigator.of(context)
                        .pushNamed('/admin_family_calendar'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.people_outline_rounded),
                    tooltip: 'إدارة أفراد العائلة',
                    onPressed: () => Navigator.of(context)
                        .pushNamed('/admin_member_management'),
                  ),
                ]);
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تسجيل الخروج؟'),
                  content: const Text('ستحتاج إلى تسجيل الدخول مجدداً للوصول إلى بيانات عائلتك.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('خروج', style: TextStyle(color: Colors.white)),
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
          Padding(
            padding: const EdgeInsets.only(left: 8),
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
        const Text('لا يوجد أفراد عائلة بعد',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('اضغط الزر أدناه لإضافة أول فرد في عائلتك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.grey600, height: 1.5)),
      ]),
    ),
  );

  Widget _memberList() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    itemCount: _members.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
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
        onLongPress: () => _confirmDeleteMember(member),
      );
    },
  );
}

// ── Member card ────────────────────────────────────────────────────────────────
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
                  Text('${member.age} سنة',
                      style: const TextStyle(fontSize: 13, color: AppColors.grey600)),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.grey600),
          ]),
        ),
      ),
    );
  }
}
